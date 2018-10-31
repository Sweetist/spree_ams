module Spree::QbdIntegration::Action::Order
  include Spree::QbdIntegration::Action::Order::Invoice
  include Spree::QbdIntegration::Action::Order::SalesReceipt
  include Spree::QbdIntegration::Action::Order::SalesOrder
  #
  # Order
  #
  def qbd_order_step(order_id, parent_step_id = nil)
    order = Spree::Order.find(order_id)
    order_hash = order.to_integration(
        self.integration_item.integrationable_options_for(order)
      )

    qbxml_class = self.integration_item.qbd_order_xml_class
    order_match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: order_id,
      integration_syncable_type: 'Spree::Order',
      sync_type: qbxml_class
    )

    # Sync Order
    if order_match.sync_id.nil?
      next_step = { step_type: :query, object_id: order_id, object_class: 'Spree::Order', qbxml_class: qbxml_class, qbxml_query_by: 'RefNumber', qbxml_match_by: 'TxnID' }
    elsif order_match.sync_id.empty?
      if CanceledStates.include?(order_hash.fetch(:state))
        next_step = { step_type: :terminate, next_step: :skip, object_id: order_id, object_class: 'Spree::Order', qbxml_class: qbxml_class, qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID' }
      elsif order_hash.fetch(:line_items,[]).any?{ |line_item| BUNDLE_TYPES.has_key?(line_item.fetch(:item_type)) }
        next_step = { step_type: :create, next_step: :continue, object_id: order_id, object_class: 'Spree::Order', qbxml_class: qbxml_class, qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID' }
      else
        next_step = { step_type: :create, run_callbacks: true, next_step: :skip, object_id: order_id, object_class: 'Spree::Order', qbxml_class: qbxml_class, qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID' }
      end
    elsif self.integration_item.qbd_overwrite_orders_in == 'none'
      next_step = { step_type: :terminate, next_step: :skip, object_id: order_id, object_class: 'Spree::Order', qbxml_class: qbxml_class, qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID' }
    elsif self.integration_item.qbd_overwrite_orders_in == 'sweet'
      raise "Updating orders in Sweet is not currently supported"
      next_step = { step_type: :pull, run_callbacks: true, object_id: order_id, object_class: 'Spree::Order', qbxml_class: qbxml_class, qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID' }
    else
      if CanceledStates.include?(order_hash.fetch(:state))
        next_step = { step_type: :void, run_callbacks: true, object_id: order_id, object_class: 'Spree::Order', qbxml_class: qbxml_class, qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID' }
      else
        next_step = { step_type: :push, run_callbacks: true, object_id: order_id, object_class: 'Spree::Order', qbxml_class: qbxml_class, qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID' }
      end
    end

    order_step = qbd_create_step(next_step)

    unless CanceledStates.include?(order_hash.fetch(:state)) || order_match.sync_id.nil?
    # Sync account
      account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: order_hash.fetch(:account_id), integration_syncable_type: 'Spree::Account')
      if account_match.synced_at.nil? || (self.integration_item.qbd_update_related_objects && account_match.synced_at < Time.current - 10.minute)
        qbd_create_step(
          self.qbd_account_step(account_match.integration_syncable_id, order_step.id),
          order_step.try(:id)
        )
      end

      if order_hash.fetch(:txn_class_id)
        txn_class_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: order_hash.fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
        if txn_class_match.synced_at.nil? || txn_class_match.synced_at < Time.current - 10.minute
          qbd_create_step(
            self.qbd_transaction_class_step(txn_class_match.integration_syncable_id, order_step.id),
            order_step.try(:id)
          )
        end
      end
      # Sync Variants
      order_hash.fetch(:line_items, []).each do |line_item|
        variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
        if variant_match.synced_at.nil? || (self.integration_item.qbd_update_related_objects && variant_match.synced_at < Time.current - 10.minute)
          qbd_create_step(
            self.qbd_variant_step(variant_match.integration_syncable_id, order_step.id),
            order_step.try(:id)
          )
        end
      end
      # Sync Tax Categories
      if self.integration_item.try(:qbd_collect_taxes)
        order_hash.fetch(:line_items, [])
                  .map {|li| li.fetch(:tax_category_id, nil)}
                  .compact.uniq.each do |tax_category_id|
                    category_match = self.integration_item.integration_sync_matches.find_or_create_by(
                      integration_syncable_id: tax_category_id,
                      integration_syncable_type: 'Spree::TaxCategory'
                    )
                    if category_match.synced_at.nil? || category_match.synced_at < Time.current - 10.minute
                      qbd_create_step(
                        self.qbd_tax_category_step(category_match.integration_syncable_id, order_step.id),
                        order_step.id
                      )
                    end
                  end
      end

      # Sync Classes
      order_hash.fetch(:line_items, [])
                .map {|li| li.fetch(:txn_class_id, nil)}
                .compact.uniq.each do |txn_class_id|
                  txn_class_match = self.integration_item.integration_sync_matches.find_or_create_by(
                    integration_syncable_id: txn_class_id,
                    integration_syncable_type: 'Spree::TransactionClass'
                  )
                  if txn_class_match.synced_at.nil? || txn_class_match.synced_at < Time.current - 10.minute
                    qbd_create_step(
                      self.qbd_transaction_class_step(txn_class_match.integration_syncable_id, order_step.id),
                      order_step.id
                    )
                  end
                end

      # Sync ShippingMethod
      if order_hash.fetch(:shipping_method_id)
        shipping_method_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: order_hash.fetch(:shipping_method_id), integration_syncable_type: 'Spree::ShippingMethod')
        if shipping_method_match.synced_at.nil? || shipping_method_match.synced_at < Time.current - 10.minute
          qbd_create_step(
            self.qbd_shipping_method_step(shipping_method_match.integration_syncable_id, order_step.id),
            order_step.try(:id)
          )
        end
      end

      if self.integration_item.qbd_use_multi_site_inventory
        # Sync Stock Locations
        order_hash.fetch(:shipments, []).each do |shipment|
          if shipment.fetch(:stock_location_id)
            stock_location_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: shipment.fetch(:stock_location_id), integration_syncable_type: 'Spree::StockLocation')
            if stock_location_match.synced_at.nil? || stock_location_match.synced_at < Time.current - 10.minute
              qbd_create_step(
                self.qbd_stock_location_step(stock_location_match.integration_syncable_id, order_step.id),
                order_step.try(:id)
              )
            end
          end
        end
      end
    end

    # TODO
    # Find or Create Grouped Discount Item
    # unless order_hash.fetch(:adjustments, {}).fetch(:sum) == 0
    #   return self.qbd_find_or_create_item_other_charge(:qbd_discount_item_name, 'ItemDiscount')
    # end

    sync_step = next_integration_step

    sync_step.try(:details) || next_step
  end

  def qbd_sales_line_description(item_hash)
    description = item_hash.fetch(:fully_qualified_description)
    if integration_item.qbd_track_lots
      if (item_hash.fetch(:item_type) == 'inventory_assembly' &&
          !integration_item.qbd_include_assembly_lots &&
          item_hash.fetch(:top_level_lot).present?)

        description += "\n#{item_hash.fetch(:top_level_lot)}"
      elsif item_hash.fetch(:lot_number).present?
        description += "\n#{item_hash.fetch(:lot_number)}"
      end
    end

    description
  end

  def qbd_order_find_by_name(ref_number, channel = nil)
    invoice = self.company.sales_invoices.where(
      number: ref_number
    ).last

    if invoice.nil? || invoice.multi_order || invoice.orders.blank?
      order = self.company.sales_orders.where(
        number: Spree::Order.number_from_integration(ref_number, self.company.id)
      ).first
    else
      order = invoice.orders.first
    end

    (channel.blank? || order.try(:channel) == channel) ? order : nil
  end

  def qbd_find_order_by_id_or_name(hash, base_key, qbxml_class = nil)
    qbxml_class ||= self.integration_item.qbd_order_xml_class
    if base_key
      qbd_order_id = hash.fetch(base_key, {}).fetch('TxnID', nil)
      qbd_order_number = hash.fetch(base_key, {}).fetch('RefNumber', nil)
    else
      qbd_order_id = hash.fetch('TxnID', nil)
      qbd_order_number = hash.fetch('RefNumber', nil)
    end
    return nil unless qbd_order_id.present? || qbd_order_number.present?

    order_match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::Order',
      sync_id: qbd_order_id,
      sync_type: qbxml_class
    ).first

    order = self.company.sales_orders.where(id: order_match.try(:integration_syncable_id)).first
    order ||= qbd_order_find_by_name(qbd_order_number)

    if order.nil?
      sync_step = self.integration_steps.find_or_initialize_by(
        integrationable_type: 'Spree::Order',
        sync_type: qbxml_class,
        sync_id: qbd_order_id
      )
      sync_step.parent_id ||= self.current_step.try(:id)
      sync_step.details = {
        step_type: :pull, object_class: 'Spree::Order', qbxml_class: qbxml_class,
        qbxml_query_by: 'TxnID', qbxml_match_by: 'TxnID', sync_id: qbd_order_id
      }

      sync_step.save
    end

    order
  end

  def qbd_order_create(qbd_hash, qbxml_class)
    Sidekiq::Client.push(
      'class' => PullObjectWorker,
      'queue' => 'integrations',
      'args' => [
        self.integration_item_id,
        'Spree::Order',
        qbxml_class,
        qbd_hash.fetch('TxnID'),
        qbd_hash.fetch('RefNumber', nil)
      ]
    )

    return
  end

  def qbd_create_order_callback_steps(order_id)
    return unless self.integration_item.qbd_use_external_balance
    order_hash = self.company.sales_orders.friendly.find(order_id).to_integration
    # qbd_create_step(
    #   self.qbd_account_step(order_hash.fetch(:account_id), current_step.try(:id)).merge(force_create: true)
    # )

    self.company
        .customer_accounts
        .find_by_id(order_hash.fetch(:account_id))
        .try(:notify_integration)
  end

end
