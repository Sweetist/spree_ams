module Spree::QboIntegration::Action
  include Spree::QboIntegration::Helper
  include Spree::QboIntegration::Action::ChartAccount
  include Spree::QboIntegration::Action::Variant
  include Spree::QboIntegration::Action::Category
  include Spree::QboIntegration::Action::TxnClass
  include Spree::QboIntegration::Action::PaymentMethod
  include Spree::QboIntegration::Action::Payment
  include Spree::QboIntegration::Action::AccountPayment
  include Spree::QboIntegration::Action::PaymentTerm
  include Spree::QboIntegration::Action::Vendor
  include Spree::QboIntegration::Action::PurchaseOrder
  include Spree::QboIntegration::Action::Bill

  def qbo_trigger(integrationable_id, integrationable_type, integration_action)
    self.update_columns(status: 1)
    if self.integration_item.qbo_company_name.blank?
      { status: -1, log: 'You are not connected to Quickbooks' }
    else
      case integrationable_type
      when 'Spree::Order'
        order = self.company.sales_orders.find_by_id(integrationable_id)
        if order.present?
          self.qbo_synchronize_order(integrationable_id, integrationable_type)
        else
          order = self.company.purchase_orders.find_by_id(integrationable_id)
          if self.integration_item.qbo_bill_from_po && States[order.state] >= States['shipped']
            self.qbo_synchronize_bill(integrationable_id, integrationable_type)
          else
            self.qbo_synchronize_purchase_order(integrationable_id, integrationable_type)
          end
        end
      when 'Spree::Account'
        account = self.company.customer_accounts.find_by_id(integrationable_id)
        if account.present?
          self.qbo_synchronize_customer(integrationable_id, integrationable_type)
        else
          self.qbo_synchronize_vendor(integrationable_id, integrationable_type)
        end
      when 'Spree::Variant'
        self.qbo_synchronize_variant(integrationable_id, integrationable_type)
      when 'Spree::StockTransfer'
        self.qbo_synchronize_stock(integrationable_id, integrationable_type)
      when 'Spree::Payment'
        self.qbo_synchronize_payment(integrationable_id, integrationable_type)
      when 'Spree::AccountPayment'
        self.qbo_synchronize_account_payment(integrationable_id, integrationable_type)
      else
        { status: -1, log: 'Unknown Integrationable Type' }
      end
    end
  end

  def qbo_retry
    return false unless self.status == -1
    retry_errors = [
      "ThrottleExceeded",
      "You can only add or edit one",
      "were working on this at the same time",
      "Previous sync still in progress"
    ]

    if self.execution_log.to_s.include?('ThrottleExceeded')
      Sidekiq::Queue[self.integration_item.queue_name].pause_for_ms(60000) #pause queue for 1 minute
    end

    retry_errors.any?{ |e| self.execution_log.to_s.include?(e) }
  end

  # Synchronize Order

  def qbo_synchronize_order(order_id, order_class)
    order = self.company.sales_orders.find(order_id)
    order_hash = order.to_integration(
        self.integration_item.integrationable_options_for(order)
      )
    service = self.integration_item.qbo_service(self.integration_item.qbo_send_order_as)
    puts '-----------'
    puts "SYNC ACCOUNT FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    sync_account = self.qbo_synchronize_customer(order_hash.fetch(:account_id), 'Spree::Account')
    if sync_account.fetch(:status) == 10
      account_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: order_hash.fetch(:account_id), integration_syncable_type: 'Spree::Account')
      qbo_customer_id = account_match.try(:sync_id)
    else
      return sync_account
    end
    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: order_id,
      integration_syncable_type: order_class,
      sync_type: "Quickbooks::Model::#{self.integration_item.qbo_send_order_as}"
    )

    if match.sync_id
      # we have match, push data
      qbo_order = service.fetch_by_id(match.sync_id)
      qbo_update_order(order_hash, qbo_order, service, qbo_customer_id)
    else
      # try to match by name
      qbo_order = service.query("
        select * from #{self.integration_item.qbo_send_order_as}
        where DocNumber='#{self.qbo_safe_string(order_hash.fetch(:fully_qualified_name))}'
        and CustomerRef='#{account_match.try(:sync_id)}'
      ").first
      if qbo_order
        # we have a match, save ID
        if( self.integration_item.qbo_include_department &&
            self.integration_item.qbo_enforce_channel &&
            qbo_order.try(:department_ref).try(:name) != order_hash.fetch(:channel)
          )
          raise Exception.new("#{self.integration_item.qbo_send_order_as} with number #{order_hash.fetch(:number)} already exists in Quickbooks.")
        end
        match.sync_id = qbo_order.id
        match.sync_type = qbo_order.class.to_s
        match.save
        qbo_update_order(order_hash, qbo_order, service, qbo_customer_id)
      elsif ['void', 'canceled', 'cancelled'].include?(order_hash.fetch(:state, nil))
        match.destroy!
        self.destroy!
        { status: -10, log: "#{order_hash.fetch(:name_for_integration)} => #{order_hash.fetch(:state)} -- Order not sent to Quickbooks" }
      else
        previous_sync = self.integration_item.reload.integration_actions.where(
            integrationable_type: 'Spree::Order',
            integrationable_id: order_id)
            .where('enqueued_at <= ?', self.enqueued_at)
            .where.not(id: self.id)
            .order(enqueued_at: :desc).first
        if [0, 1].include?(previous_sync.try(:status))
          Airbrake.notify(
            error_message: "Previous sync still in progress - possible order duplication",
            error_class: "SidekiqRaceError",
            parameters: {
              integration_item_id: self.try(:integration_item_id),
              order_id: order_id,
              vendor_id: self.try(:company).try(:id),
              vendor_name: self.try(:company).try(:name),
              order_match: match.try(:attributes).except('no_sync'),
              account_match: account_match.try(:attributes).except('no_sync')
            }
          )
          return { status: -1, log: "Previous sync still in progress." }
        end

        # no match, create new!
        if self.integration_item.qbo_send_as_invoice
          qbo_new_order = qbo_order_to_qbo_order(Quickbooks::Model::Invoice.new, order_hash, qbo_customer_id)
        else
          qbo_new_order = qbo_order_to_qbo_order(Quickbooks::Model::SalesReceipt.new, order_hash, qbo_customer_id)
        end
        if qbo_new_order.class == Hash
          return qbo_new_order
        else
          response = service.create(qbo_new_order)
          match.sync_id = response.id
          match.sync_type = response.class.to_s
          match.save
          { status: 10, log: "#{order_hash.fetch(:name_for_integration)} => Pushed." }
        end
      end
    end
  rescue Exception => e
    Airbrake.notify(
      error_message: "#{e.class.to_s} - #{e.message}",
      error_class: "QBO Order Sync"
    )
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end

  def qbo_update_order(order_hash, qbo_order, service, qbo_customer_id)
    if ['void', 'canceled', 'cancelled'].include?(order_hash.fetch(:state))
      service.void(qbo_order)
    else
      qbo_updated_order = qbo_order_to_qbo_order(qbo_order, order_hash, qbo_customer_id)
      if qbo_updated_order.class == Hash
        return qbo_updated_order
      else
        puts '-----------'
        puts "CALL QBO SERVICE FOR ORDER #{order_hash.fetch(:number)}"
        puts '-----------'
        service.update(qbo_updated_order)
      end
    end
    { status: 10, log: "#{order_hash.fetch(:name_for_integration)} => Match updated in QBO." }
  end

  def qbo_order_to_qbo_order(qbo_order, order_hash, qbo_customer_id)
    puts '-----------'
    puts "BEGIN QBO ORDER MAPPING FOR #{order_hash.fetch(:number)}"
    puts '-----------'

    if integration_item.qbo_multi_currency
      qbo_order.currency_ref = Quickbooks::Model::BaseReference.new(order_hash.fetch(:currency))
      qbo_order.exchange_rate = qbo_exchange_rate(order_hash.fetch(:currency))  #Need to supply an exchange rate for multi-currency
    end

    # Date fields
    qbo_order.txn_date = order_hash.fetch(:invoice_date)
    if self.integration_item.qbo_send_order_as.to_s.downcase == 'invoice'
      qbo_order.due_date = order_hash.fetch(:due_date)
    end
    unless self.vendor.try(:order_date_text).to_s.downcase == 'none'
      qbo_order.ship_date = order_hash.fetch(:delivery_date)
    end

    qbo_order.doc_number = order_hash.fetch(:number)
    qbo_order.tracking_num = order_hash.fetch(:shipments, []).map do |shipment|
      shipment.fetch(:tracking, nil)
    end.reject(&:blank?).join(', ')
    if self.integration_item.qbo_include_department
      puts '-----------'
      puts "MAPPING QBO DEPARTMENT FOR ORDER #{order_hash.fetch(:number)}"
      puts '-----------'
      department_service = self.integration_item.qbo_service('Department')
      qbo_department = department_service.query("select * from Department where FullyQualifiedName='#{order_hash.fetch(:channel)}'").first
      if qbo_department.nil?
        new_department = Quickbooks::Model::Department.new
        new_department.name = order_hash.fetch(:channel, '')
        qbo_department = department_service.create(new_department)
      end

      qbo_order.department_ref = Quickbooks::Model::BaseReference.new(qbo_department.try(:id))
    end

    if order_hash.fetch(:txn_class_id)
      txn_class_sync = qbo_synchronize_transaction_class(order_hash.fetch(:txn_class_id))
      unless txn_class_sync.fetch(:status) == 10
        raise Exception.new("Class: #{txn_class_sync.fetch(:log, "An error occured while syncing a class")}")
      end
      qbo_class_id = self.integration_item.integration_sync_matches.find_by(
        integration_syncable_type: 'Spree::TransactionClass',
        integration_syncable_id: order_hash.fetch(:txn_class_id)
      ).try(:sync_id)
      qbo_order.class_ref = Quickbooks::Model::BaseReference.new(qbo_class_id)
    end

    if self.integration_item.qbo_send_as_invoice && order_hash.fetch(:payment_term_id, nil)
      qbo_term_id = self.integration_item.integration_sync_matches.find_by(
        integration_syncable_type: 'Spree::PaymentTerm',
        integration_syncable_id: order_hash.fetch(:payment_term_id)
      ).try(:sync_id)

      qbo_order.sales_term_ref = Quickbooks::Model::BaseReference.new(qbo_term_id) if qbo_term_id
    end

    # Account
    puts '-----------'
    puts "MAPPING QBO CUSTOMER ID FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    qbo_order.customer_ref = Quickbooks::Model::BaseReference.new(qbo_customer_id)
    puts '-----------'
    puts "BEGIN MAPPING QBO LINE ITEMS FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    # Line Items
    qbo_order.txn_tax_detail = Quickbooks::Model::TransactionTaxDetail.new(lines: [])
    qbo_order.line_items = []
    order_hash.fetch(:line_items, []).each_with_index do |line_item_hash, index|
      qbo_line_item = Quickbooks::Model::InvoiceLineItem.new
      qbo_line_item.amount = line_item_hash.fetch(:amount)

      if BUNDLE_TYPES.has_key?(line_item_hash.fetch(:item_type))
        qbo_line_item.amount = 0
        qbo_line_item.detail_type = 'GroupLineDetail'
        #Classes not supported on GroupLine
        qbo_group_line_detail = Quickbooks::Model::InvoiceGroupLineDetail.new
        sync_variant = self.qbo_synchronize_variant(line_item_hash.fetch(:variant_id), 'Spree::Variant')
        if sync_variant.fetch(:status) >= 3 #match but warn that is not updated - use this because bundle items cannot be updated via API
          variant = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: line_item_hash.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
          qbo_group_line_detail.group_item_ref = Quickbooks::Model::BaseReference.new(variant.try(:sync_id))
        else
          return sync_variant
        end
        qbo_group_line_detail.quantity = line_item_hash.fetch(:quantity)

        parts_variants = line_item_hash.fetch(:parts_variants,[])

        qbo_group_line_detail.line_items = parts_variants.map do |part_variant|
          qbo_group_line = Quickbooks::Model::InvoiceLineItem.new
          qbo_group_line.amount = part_variant.fetch(:amount)
          qbo_group_line.description = qbo_sales_line_description(part_variant)
          #part_variant.fetch(:fully_qualified_description)
          qbo_group_line.detail_type = 'SalesItemLineDetail'
          qbo_sales_line_detail(qbo_order, qbo_group_line, part_variant, index)
        end

        parts_amount = line_item_hash.fetch(:parts_variants).map{|ap| ap.fetch(:amount) }.inject(:+) || 0
        bundle_adj_amount = line_item_hash.fetch(:amount) - parts_amount
        unless bundle_adj_amount == 0
          bundle_adj_line = qbo_bundle_adjustment(qbo_order, bundle_adj_amount, line_item_hash, index)
          qbo_group_line_detail.line_items << bundle_adj_line
        end
        qbo_line_item.group_line_detail = qbo_group_line_detail
        qbo_order.line_items << qbo_line_item
      else
        qbo_line_item.description = qbo_sales_line_description(line_item_hash)


        qbo_line_item.detail_type = 'SalesItemLineDetail'
        qbo_order.line_items << qbo_sales_line_detail(qbo_order, qbo_line_item, line_item_hash, index)
      end
    end
    puts '-----------'
    puts "END MAPPING QBO LINE ITEMS FOR ORDER #{order_hash.fetch(:number)}"
    puts "BEGIN MAPPING QBO SHIPPING FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    # Shipping -- send shipping if feature enabled
    if self.integration_item.qbo_include_shipping && order_hash.fetch(:shipping_method, {}).fetch(:shipment_total)
      qbo_order.ship_method_ref = Quickbooks::Model::BaseReference.new(order_hash.fetch(:shipping_method, {}).fetch(:name), name: order_hash.fetch(:shipping_method, {}).fetch(:name))
      ship_item = Quickbooks::Model::InvoiceLineItem.new
      ship_item.amount = order_hash.fetch(:shipping_method, {}).fetch(:shipment_total)
      ship_item.sales_item! do |detail|
        detail.item_ref = Quickbooks::Model::BaseReference.new('SHIPPING_ITEM_ID')
        tax_category_id = order_hash.fetch(:shipping_method, {}).fetch(:tax_category_id, nil)
        next if tax_category_id.nil?
        if order_hash.fetch(:shipping_method, {}).fetch(:additional_tax_total) || self.integration_item.qbo_country != 'US'
          qbo_tax_code = self.qbo_synchronize_tax_category(tax_category_id)
          if self.integration_item.qbo_country == 'US'
            detail.tax_code_ref = Quickbooks::Model::BaseReference.new('TAX')
          else
            detail.tax_code_ref = Quickbooks::Model::BaseReference.new(qbo_tax_code.try(:id))
          end
          tax_line_detail = Quickbooks::Model::TaxLineDetail.new
          tax_line_detail.tax_rate_ref = Quickbooks::Model::BaseReference.new(qbo_tax_code.sales_tax_rate_list.tax_rate_detail.first.tax_rate_ref.value)
          tax_line = Quickbooks::Model::TaxLine.new
          tax_line.detail_type = 'TaxLineDetail'
          tax_line.tax_line_detail = tax_line_detail
          qbo_order.txn_tax_detail.lines << tax_line
          qbo_order.txn_tax_detail.txn_tax_code_ref ||= Quickbooks::Model::BaseReference.new(qbo_tax_code.try(:id))
        end
      end
      qbo_order.line_items << ship_item
    end
    # Discounts
    puts '-----------'
    puts "MAPPING QBO DISCOUNTS FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    if self.integration_item.qbo_include_discounts
      qbo_discount_item = qbo_order_discount(order_hash)
      qbo_order.line_items << qbo_discount_item
    end
    # Custom Fields
    puts '-----------'
    puts "MAPPING QBO CUSTOM FIELDS FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    qbo_order.custom_fields = [] if qbo_order.custom_fields.nil?
    [1,2,3].each do |n|
      custom_attr = self.integration_item.send("qbo_custom_field_#{n}")
      next if custom_attr.blank?

      custom_field = qbo_order.custom_fields.find {|f| f.id == n }
      if custom_field.nil?
        custom_field = Quickbooks::Model::CustomField.new(
          id: n,
          name: self.integration_item.qbo_custom_field_options.to_h.key(custom_attr),
          type: 'StringType'
        )
        qbo_order.custom_fields << custom_field
      end
      custom_field.string_value = order_hash.fetch(custom_attr.to_sym)
    end

    #BillAddress
    puts '-----------'
    puts "MAPPING QBO BILL ADDRESS FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    bill_address = order_hash.fetch(:bill_address)
    billing_address_hash = bill_address.try(
        :to_integration,
        self.integration_item.integrationable_options_for(bill_address)
      ) || {}
    qbo_order.billing_address = self.qbo_address_to_qbo(Quickbooks::Model::PhysicalAddress.new, billing_address_hash, true)
    qbo_order.billing_email_address = qbo_split_email(order_hash.fetch(:email,''))
    #ShipAddress
    puts '-----------'
    puts "MAPPING QBO SHIP ADDRESS FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    ship_address = order_hash.fetch(:ship_address)
    shipping_address_hash = ship_address.try(
        :to_integration,
        self.integration_item.integrationable_options_for(ship_address)
      ) || {}
    qbo_order.shipping_address = self.qbo_address_to_qbo(Quickbooks::Model::PhysicalAddress.new, shipping_address_hash, true)

    # Customer Memo
    puts '-----------'
    puts "MAPPING QBO CUSTOMER MEMO FOR ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    qbo_order.customer_memo = order_hash.fetch(:special_instructions)
    puts '-----------'
    puts "FINISH MAPPING ORDER #{order_hash.fetch(:number)}"
    puts '-----------'
    qbo_order
  end

  def qbo_split_email(email_str)
    limited_email_str = ''
    email_str.split.each do |email|
      email = email.gsub(/[\s,]/ ,"")
      break if limited_email_str.length + email.length > 99
      limited_email_str += "#{email},"
    end
    limited_email_str[0..-2]
  end

  def qbo_sales_line_detail(qbo_order, qbo_line_item, line_item_hash, index)
    qbo_line_item.sales_item! do |detail|
      puts '-----------'
      puts "SYNCING VARIANT #{line_item_hash.fetch(:fully_qualified_description,'')}"
      puts '-----------'
      sync_variant = self.qbo_synchronize_variant(line_item_hash.fetch(:variant_id), 'Spree::Variant')
      puts '-----------'
      puts "FINISH SYNCING VARIANT"
      puts '-----------'

      if sync_variant.fetch(:status) == 10
        variant = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: line_item_hash.fetch(:variant_id), integration_syncable_type: 'Spree::Variant')
        detail.item_ref = Quickbooks::Model::BaseReference.new(variant.try(:sync_id))
      else
        raise Exception.new("#{line_item_hash.fetch(:item_name,'').strip} #{sync_variant.fetch(:log, "An error occured while syncing a product")}")
        # return sync_variant
      end

      if line_item_hash.fetch(:txn_class_id)
        txn_class_sync = qbo_synchronize_transaction_class(line_item_hash.fetch(:txn_class_id))
        unless txn_class_sync.fetch(:status) == 10
          raise Exception.new("Class: #{txn_class_sync.fetch(:log, "An error occured while syncing a class")}")
        end
        qbo_class_id = self.integration_item.integration_sync_matches.find_by(
          integration_syncable_type: 'Spree::TransactionClass',
          integration_syncable_id: line_item_hash.fetch(:txn_class_id)
        ).try(:sync_id)
        detail.class_ref = Quickbooks::Model::BaseReference.new(qbo_class_id)
      end
      detail.unit_price = line_item_hash.fetch(:discount_price)
      detail.quantity = line_item_hash.fetch(:quantity)

      if line_item_hash.fetch(:adjustments, {}).fetch(:is_tax_present) || self.integration_item.qbo_country != 'US'
        qbo_tax_code = self.qbo_synchronize_tax_category(line_item_hash.fetch(:tax_category_id))
        if self.integration_item.qbo_country == 'US'
          detail.tax_code_ref = Quickbooks::Model::BaseReference.new('TAX')
        else
          detail.tax_code_ref = Quickbooks::Model::BaseReference.new(qbo_tax_code.try(:id))
        end
        tax_line_detail = Quickbooks::Model::TaxLineDetail.new
        tax_line_detail.tax_rate_ref = Quickbooks::Model::BaseReference.new(qbo_tax_code.sales_tax_rate_list.tax_rate_detail.first.tax_rate_ref.value)
        tax_line = Quickbooks::Model::TaxLine.new
        tax_line.detail_type = 'TaxLineDetail'
        tax_line.line_num = index + 1
        tax_line.tax_line_detail = tax_line_detail
        qbo_order.txn_tax_detail.lines << tax_line
        qbo_order.txn_tax_detail.txn_tax_code_ref = Quickbooks::Model::BaseReference.new(qbo_tax_code.try(:id))
      else
        detail.tax_code_ref = Quickbooks::Model::BaseReference.new('NON')
      end
    end

    qbo_line_item
  end

  def qbo_sales_line_description(item_hash)
    description = item_hash.fetch(self.integration_item.qbo_send_to_line_description.to_sym)
    if integration_item.qbo_include_lots
      if (item_hash.fetch(:item_type) == 'inventory_assembly' &&
          !integration_item.qbo_include_assembly_lots &&
          item_hash.fetch(:top_level_lot).present?)

        description += "\n#{item_hash.fetch(:top_level_lot)}"
      elsif item_hash.fetch(:lot_number).present?
        description += "\n#{item_hash.fetch(:lot_number)}"
      end
    end

    ActionView::Base.full_sanitizer.sanitize(qbo_safe_string(description))
  end

  def qbo_bundle_adjustment(qbo_order, bundle_adj_amount, line_item_hash, index)
    bundle_adj_line = Quickbooks::Model::InvoiceLineItem.new

    bundle_adj_line.detail_type = 'SalesItemLineDetail'

    bundle_adj_line.sales_item! do |detail|
      if self.integration_item.qbo_bundle_adjustment_name.blank?
        return {status: -1, log: "Must supply a bundle adjustment name"}
      else
        service = self.integration_item.qbo_service('Item')
        qbo_item = service.find_by(:name, self.integration_item.qbo_bundle_adjustment_name).first
        if qbo_item
          item_ref = Quickbooks::Model::BaseReference.new(qbo_item.try(:id))
        elsif self.integration_item.qbo_create_related_objects
          #
          bundle_adj_hash = {
            name: self.integration_item.qbo_bundle_adjustment_name,
            description: 'Adjusts the final price of a bundle when the bundle price is not equal to the sum of its parts',
            price: 0,
            income_account_id: self.integration_item.qbo_bundle_adjustment_account_id,
            variant_type: 'NonInventory',
            track_inventory: false
          }

          qbo_new_item = qbo_variant_to_qbo(Quickbooks::Model::Item.new, bundle_adj_hash)
          qbo_item = service.create(qbo_new_item)

          item_ref = Quickbooks::Model::BaseReference.new(qbo_item.try(:id))
        else
          # no match, no create
          raise Exception.new("Unable to find Match for Bundle Adjustment: #{self.integration_item.qbo_bundle_adjustment_name}")
        end
        detail.item_ref = item_ref
      end

      # uncomment qty options below to send one adj per bundle qty
      detail.quantity = 1# line_item_hash.fetch(:quantity)
      detail.unit_price = bundle_adj_amount #/ line_item_hash.fetch(:quantity)
      bundle_adj_line.amount = detail.unit_price
      if line_item_hash.fetch(:adjustments, {}).fetch(:is_tax_present) || self.integration_item.qbo_country != 'US'
        qbo_tax_code = self.qbo_synchronize_tax_category(line_item_hash.fetch(:tax_category_id))
        if self.integration_item.qbo_country == 'US'
          detail.tax_code_ref = Quickbooks::Model::BaseReference.new('TAX')
        else
          detail.tax_code_ref = Quickbooks::Model::BaseReference.new(qbo_tax_code.try(:id))
        end
        tax_line_detail = Quickbooks::Model::TaxLineDetail.new
        tax_line_detail.tax_rate_ref = Quickbooks::Model::BaseReference.new(qbo_tax_code.sales_tax_rate_list.tax_rate_detail.first.tax_rate_ref.value)
        tax_line = Quickbooks::Model::TaxLine.new
        tax_line.detail_type = 'TaxLineDetail'
        tax_line.line_num = index + 1
        tax_line.tax_line_detail = tax_line_detail
        qbo_order.txn_tax_detail.lines << tax_line
        qbo_order.txn_tax_detail.txn_tax_code_ref = Quickbooks::Model::BaseReference.new(qbo_tax_code.try(:id))
      else
        detail.tax_code_ref = Quickbooks::Model::BaseReference.new('NON')
      end
    end

    bundle_adj_line
  end

  def qbo_order_discount(order_hash)
    disc_item = Quickbooks::Model::InvoiceLineItem.new
    disc_item.amount = order_hash.fetch(:adjustments, {}).fetch(:sum) * -1 # it expects possitive value as a discount.
    disc_item.detail_type = 'DiscountLineDetail'
    disc_detail = Quickbooks::Model::DiscountLineDetail.new
    disc_account = Spree::ChartAccount.find_by_id(self.integration_item.qbo_discount_account_id)
    disc_account ||= Spree::ChartAccount.find_by_id(order_hash.fetch(:adjustments, {}).fetch(:discount_account_id))

    if disc_account
      qbo_synchronize_chart_account(disc_account.id)
      disc_account_match = self.integration_sync_matches.where(
        integration_syncable_id: disc_account.id,
        integration_syncable_type: 'Spree::ChartAccount'
      ).first
      qbo_disc_account = self.integration_item.qbo_service('Account').fetch_by_id(disc_account_match.try(:sync_id))
      if qbo_disc_account
        disc_ref = Quickbooks::Model::BaseReference.new(qbo_disc_account.try(:id))
        disc_ref.name = qbo_disc_account.try(:name)
        disc_detail.discount_account_ref = disc_ref
        disc_item.discount_line_detail = disc_detail

        disc_item
      else
        raise Exception.new("Quickbooks could not find an Account with name: #{disc_account.try(:name)}")
      end
    else
      raise Exception.new("Unable to find the discount account in Sweet. Please ensure one is specified for the integration.")
    end
  end

  # Synchronize Tax Category
  def qbo_synchronize_tax_category(tax_category_id)
    tax_category = Spree::TaxCategory.find(tax_category_id)
    tax_code = self.integration_item.qbo_service('TaxCode').find_by(:name, self.qbo_safe_string(tax_category.name)).first
    if tax_code.nil?
      service = self.integration_item.qbo_service('TaxService')
      tax_service = Quickbooks::Model::TaxService.new
      tax_service.tax_code = tax_category.name
      if tax_category.tax_rates.empty?
        raise "You must supply at least 1 Tax Rate for Tax Category '#{tax_category.name}'. Tax Rates can be added under the 'Configurations' tab of the side menu."
      end
      tax_service.tax_rate_details = tax_category.tax_rates.map do |rate|
        agency = self.integration_item.qbo_service('TaxAgency').find_by(:name, self.qbo_safe_string(rate.zone.name)).first
        if agency.nil?
          agency = self.integration_item.qbo_service('TaxAgency').create(Quickbooks::Model::TaxAgency.new(display_name: rate.zone.name))
        end
        tax_rate_detail = Quickbooks::Model::TaxRateDetailLine.new
        tax_rate_detail.tax_rate_name = rate.name
        tax_rate_detail.rate_value = rate.amount.to_f * 100
        tax_rate_detail.tax_agency_id = agency.try(:id)
        tax_rate_detail.tax_applicable_on = 'Sales'
        tax_rate_detail
      end
      service.create(tax_service)
      tax_code = self.integration_item.qbo_service('TaxCode').find_by(:name, self.qbo_safe_string(tax_category.name)).first
    end

    if tax_code.nil?
      raise "Unable to find TaxCode with name '#{tax_category.name}' in Quickbooks."
    end
    tax_code
  end

  # Synchronize Account

  def qbo_synchronize_customer(account_id, account_class)
    account = Spree::Account.find(account_id)
    account_hash = account.to_integration(
        self.integration_item.integrationable_options_for(account)
      )
    qbo_customer_company = {}
    if account_hash.fetch(:account,{}).fetch(:sub_customer)
      qbo_customer_company = qbo_synchronize_parent_account(account_hash.fetch(:account,{}).fetch(:parent_id, nil), account_class)
    end

    if qbo_customer_company.fetch(:status, 10) == 10
      account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_id, integration_syncable_type: account_class)
      service = self.integration_item.qbo_service('Customer')
      if account_match.sync_id
        # we have account_match, push data
        qbo_customer = service.fetch_by_id(account_match.sync_id)
        qbo_update_customer(account_hash, qbo_customer, service)
      else
        # try to match by name
        if account_hash.fetch(:account,{}).fetch(:sub_customer)
          qbo_customer = service.find_by(:display_name, self.qbo_safe_string(account_hash.fetch(:account,{}).fetch(:name))).first
        else
          qbo_customer = service.find_by(:display_name, self.qbo_safe_string(account_hash.fetch(:fully_qualified_name))).first
        end
        if qbo_customer
          # we have a account_match, save ID
          account_match.sync_id = qbo_customer.id
          account_match.sync_type = qbo_customer.class.to_s
          account_match.save
          qbo_update_customer(account_hash, qbo_customer, service)
        else
          # no account_match
          if self.integration_item.qbo_create_related_objects
            # no account_match, create new!
            qbo_new_customer = qbo_customer_to_qbo(Quickbooks::Model::Customer.new, account_hash.fetch(:account, {}))
            response = service.create(qbo_new_customer)
            account_match.sync_id = response.id
            account_match.sync_type = response.class.to_s
            account_match.save
            { status: 10, log: "#{account_hash.fetch(:account, {}).fetch(:name_for_integration)} => Pushed." }
          else
            # no account_match, no create
            { status: -1, log: "#{account_hash.fetch(:account, {}).fetch(:name_for_integration)} => Unable to find account_match" }
          end
        end
      end
    else
      qbo_customer_company
    end
    rescue Exception => e
      { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end

  def qbo_update_customer(account_hash, qbo_customer, service)
    if self.integration_item.qbo_customer_overwrite_conflicts_in == 'quickbooks'
      qbo_updated_customer = qbo_customer_to_qbo(qbo_customer, account_hash.fetch(:account,{}))
      service.update(qbo_updated_customer)
      { status: 10, log: "#{account_hash.fetch(:account, {}).fetch(:name_for_integration)} => account match updated in QBO." }
    elsif self.integration_item.qbo_customer_overwrite_conflicts_in == 'sweet'
      account_hash.fetch(:account, {}).fetch(:self).from_integration({
        account: self.qbo_customer_to_account(qbo_customer),
        ship_address: self.qbo_customer_to_ship_address(qbo_customer, account_hash),
        bill_address: self.qbo_customer_to_bill_address(qbo_customer, account_hash)
      })
      { status: 10, log: "#{account_hash.fetch(:account, {}).fetch(:name_for_integration)} => account match updated in Sweet." }
    else
      { status: 10, log: "#{account_hash.fetch(:account, {}).fetch(:name_for_integration)} => Customer matched without update." }
    end
  end

  # Synchronize Parent Account
  def qbo_synchronize_parent_account(account_id, account_class)
    account = self.company.customer_accounts.find(account_id)
    account_hash = account.to_integration(
        self.integration_item.integrationable_options_for(account)
      )
    parent_account_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_id, integration_syncable_type: 'Spree::Account')

    service = self.integration_item.qbo_service('Customer')
    if parent_account_match.sync_id
      # we have company_match, push data
      qbo_customer = service.fetch_by_id(parent_account_match.sync_id)
      qbo_update_customer(account_hash, qbo_customer, service)
    else
      # try to match by name
      qbo_customer = service.find_by(:display_name, self.qbo_safe_string(account_hash.fetch(:account).fetch(:name))).first
      if qbo_customer
        # we have a parent_account_match, save ID
        parent_account_match.sync_id = qbo_customer.id
        parent_account_match.sync_type = qbo_customer.class.to_s
        parent_account_match.save
        qbo_update_customer(account_hash, qbo_customer, service)
      else
        # no parent_account_match
        if self.integration_item.qbo_create_related_objects
          # no parent_account_match, create new!
          qbo_new_customer = qbo_customer_to_qbo(Quickbooks::Model::Customer.new, account_hash.fetch(:account,{}))
          response = service.create(qbo_new_customer)
          parent_account_match.sync_id = response.id
          parent_account_match.sync_type = response.class.to_s
          parent_account_match.save
          { status: 10, log: "#{account_hash.fetch(:account, {}).fetch(:name_for_integration)} => Pushed." }
        else
          # no parent_account_match, no create
          { status: -1, log: "#{account_hash.fetch(:account, {}).fetch(:name_for_integration)} => Unable to find parent account match" }
        end
      end
    end
  rescue Exception => e
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end

  def qbo_customer_to_qbo(qbo_customer, account_hash)
    account = account_hash
    parent_account_match = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: account_hash.fetch(:parent_id), integration_syncable_type: 'Spree::Account')

    if account.fetch(:sub_customer, false) && parent_account_match.try(:sync_id)
      qbo_customer.given_name = account.fetch(:firstname, '')
      qbo_customer.family_name = account.fetch(:lastname, '')
      qbo_customer.display_name = account.fetch(:name, '')
      qbo_customer.company_name = account.fetch(:name, '')
      qbo_customer.job = true
      qbo_customer.parent_ref = Quickbooks::Model::BaseReference.new(parent_account_match.sync_id)
    else
      qbo_customer.given_name = account.fetch(:firstname, '')
      qbo_customer.family_name = account.fetch(:lastname, '')
      qbo_customer.company_name = account.fetch(:name, '').to_s.split(':').first.to_s
      qbo_customer.display_name = account.fetch(:name, '')
    end

    if account.fetch(:payment_term_id, nil)
      qbo_synchronize_payment_term( account.fetch(:payment_term_id))
      qbo_term_id = self.integration_item.integration_sync_matches.find_by(
        integration_syncable_type: 'Spree::PaymentTerm',
        integration_syncable_id: account.fetch(:payment_term_id)
      ).try(:sync_id)

      qbo_customer.sales_term_ref = Quickbooks::Model::BaseReference.new(qbo_term_id)
    end


    qbo_customer.active = account.fetch(:active)
    bill_address = account_hash.fetch(:billing_address, nil)
    billing_address_hash = bill_address.try(
        :to_integration,
        self.integration_item.integrationable_options_for(bill_address)
      ) || {}
    ship_address = account_hash.fetch(:shipping_address, nil)
    shipping_address_hash = ship_address.try(
        :to_integration,
        self.integration_item.integrationable_options_for(ship_address)
      ) || {}

    qbo_customer.primary_phone = self.qbo_phone_to_qbo(qbo_customer.primary_phone || Quickbooks::Model::TelephoneNumber.new, shipping_address_hash.fetch(:phone, nil))
    qbo_customer.primary_email_address = self.qbo_email_to_qbo(qbo_customer.primary_email_address || Quickbooks::Model::EmailAddress.new, account_hash.fetch(:email, nil))

    qbo_customer.billing_address = self.qbo_address_to_qbo(qbo_customer.billing_address || Quickbooks::Model::PhysicalAddress.new, billing_address_hash, false)
    qbo_customer.shipping_address = self.qbo_address_to_qbo(qbo_customer.shipping_address || Quickbooks::Model::PhysicalAddress.new, shipping_address_hash, false)

    qbo_customer
  end

  def qbo_email_to_qbo(qbo_email, email)
    qbo_email.address = email.to_s
    qbo_email unless email.blank?
  end

  def qbo_phone_to_qbo(qbo_phone, phone)
    qbo_phone.free_form_number = phone.to_s
    qbo_phone unless phone.blank?
  end

  def qbo_address_to_qbo(qbo_address, address_hash, include_company)
    unless address_hash.empty?
      if include_company && address_hash.fetch(:company, '').present?
        qbo_address.line1 = address_hash.fetch(:company, '')
        qbo_address.line2 = address_hash.fetch(:address1, '')
        qbo_address.line3 = address_hash.fetch(:address2, '')
      else
        qbo_address.line1 = address_hash.fetch(:address1, '')
        qbo_address.line2 = address_hash.fetch(:address2, '')
      end
      qbo_address.city = address_hash.fetch(:city, '')
      qbo_address.postal_code = address_hash.fetch(:zipcode, '')
      qbo_address.country = Spree::Country.where(id: address_hash.fetch(:country_id, nil)).first.try(:name).to_s
      qbo_address.country_sub_division_code = Spree::State.where(id: address_hash.fetch(:state_id, nil)).first.try(:abbr).to_s
      qbo_address
    end
  end

  def qbo_customer_to_account(qbo_customer)
    {
      name: qbo_customer.display_name,
      email: qbo_customer.primary_email_address.try(:address)
    }.compact.merge({
      inactive_date: qbo_customer.active? ? nil : Date.current
    })
  end

  def qbo_customer_to_ship_address(qbo_customer, account_hash)
    address = qbo_customer.try(:shipping_address)
    country = Spree::Country.where(name: address.try(:country)).first
    if country
      state_id = country.states.where('spree_states.abbr ILIKE ? OR spree_states.name ILIKE ?', address.try(:country_sub_division_code), address.try(:country_sub_division_code)).first.try(:id)
    elsif account_hash.fetch(:ship_address, {}).fetch(:country_id, nil)
      country = Spree::Country.find_by_id(account_hash.fetch(:ship_address, {}).fetch(:country_id, nil))
      state_id = country.states.where('spree_states.abbr ILIKE ? OR spree_states.name ILIKE ?', address.try(:country_sub_division_code), address.try(:country_sub_division_code)).first.try(:id)
    elsif self.company.try(:bill_address).try(:country).present?
      state_id = self.company.bill_address.country.states.where('spree_states.abbr ILIKE ? OR spree_states.name ILIKE ?', address.try(:country_sub_division_code), address.try(:country_sub_division_code)).first.try(:id)
    else
      state_id = Spree::State.where('spree_states.abbr ILIKE ? OR spree_states.name ILIKE ?', address.try(:country_sub_division_code), address.try(:country_sub_division_code)).first.try(:id)
    end
    {
      address1: address.try(:line1),
      address2: address.try(:line2),
      city: address.try(:city),
      zipcode: address.try(:postal_code),
      country_id: country.try(:id),
      state_id: state_id
    }
  end

  def qbo_customer_to_bill_address(qbo_customer, account_hash)
    address = qbo_customer.try(:billing_address)
    country = Spree::Country.where(name: address.try(:country)).first
    if country
      state_id = country.states.where('spree_states.abbr ILIKE ? OR spree_states.name ILIKE ?', address.try(:country_sub_division_code), address.try(:country_sub_division_code)).first.try(:id)
    elsif account_hash.fetch(:bill_address, {}).fetch(:country_id, nil)
      country = Spree::Country.find_by_id(account_hash.fetch(:bill_address, {}).fetch(:country_id, nil))
      state_id = country.states.where('spree_states.abbr ILIKE ? OR spree_states.name ILIKE ?', address.try(:country_sub_division_code), address.try(:country_sub_division_code)).first.try(:id)
    elsif self.company.try(:bill_address).try(:country).present?
      state_id = self.company.bill_address.country.states.where('spree_states.abbr ILIKE ? OR spree_states.name ILIKE ?', address.try(:country_sub_division_code), address.first.try(:country_sub_division_code)).try(:id)
    else
      state_id = Spree::State.where('spree_states.abbr ILIKE ? OR spree_states.name ILIKE ?', address.try(:country_sub_division_code), address.try(:country_sub_division_code)).first.try(:id)
    end
    {
      address1: address.try(:line1),
      address2: address.try(:line2),
      city: address.try(:city),
      zipcode: address.try(:postal_code),
      country_id: country.try(:id),
      state_id: state_id
    }
  end

  def qbo_synchronize_stock(stock_transfer_id, stock_transfer_class)
    # stock_transfer_hash = Spree::StockTransfer.find(stock_transfer_id).to_integration
    # stock_transfer_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_transfer_hash.fetch(:id), integration_syncable_type: stock_transfer_class)
    results = Hash.new([])
    stock_transfer = Spree::StockTransfer.find(stock_transfer_id)

    stock_transfer.stock_movements.includes(:stock_item).each do |sm|
      result = qbo_synchronize_variant(sm.stock_item.variant_id, 'Spree::Variant', true)
      results[result[:status].to_s] += [result[:log]]
    end

    status = results.keys.map(&:to_i).sort.first
    if status == 10 #success
      {status: status, log: "StockTransfer #{stock_transfer.name_for_integration}"}
    else
      {status: status, log: results[status.to_s].join(', ')}
    end
  end

  def qbo_variant_to_qbo(qbo_item, variant_hash, is_transfer = false)
    qbo_item.name = variant_hash.fetch(:name)
    qbo_item.sku = variant_hash.fetch(:sku, nil)
    if self.integration_item.qbo_strip_html
      qbo_item.description = ActionView::Base.full_sanitizer.sanitize(qbo_safe_string(variant_hash.fetch(:description, ''))).strip
    else
      qbo_item.description = qbo_safe_string(variant_hash.fetch(:description, '')).strip
    end
    qbo_item.unit_price = variant_hash.fetch(:price, 0)
    qbo_item.purchase_cost = variant_hash.fetch(:cost_price, nil)
    unless variant_hash.fetch(:product,{}).fetch(:has_variants, false) && variant_hash.fetch(:is_master, true)
      qbo_item.active = variant_hash.fetch(:active, true)
    end

    case variant_hash.fetch(:variant_type, 'non_inventory_item')
    when *INVENTORY_TYPES.keys
      if self.integration_item.qbo_send_as_non_inventory
        qbo_item.type = "NonInventory"
        qbo_item.track_quantity_on_hand = false
      else
        variant_hash[:parts_variants].each do |part_variant|
          qbo_synchronize_variant(part_variant[:part_id], 'Spree::Variant')
        end
        qbo_item.type = "Inventory"
        qbo_item.track_quantity_on_hand = true # variant_hash.fetch(:track_inventory) <--- if we send Inventory item, we have to track_quantity_on_hand
        site = variant_hash.fetch(:inventory_counts, []).select{|si| si.fetch(:stock_location_id).to_s == self.integration_item.qbo_track_inventory_from.to_s}.first
        qbo_item.quantity_on_hand = site ? site.fetch(:count_on_hand) : variant_hash.fetch(:total_on_hand)
        variant_hash[:fully_qualified_name]
        # According to QBO the inventory start date/trasfer date has to be after
        # the date of the last order with this item
        if qbo_item.inv_start_date.nil?
          last_order_date = variant_hash.fetch(:self).orders.complete.order('delivery_date desc').first.try(:delivery_date)
          if qbo_item.id && last_order_date
            earliest_inv_start_date = last_order_date + 1.day
          else
            earliest_inv_start_date = variant_hash.fetch(:available_on) < Time.current ? variant_hash.fetch(:available_on) : Time.current
          end
          qbo_item.inv_start_date = earliest_inv_start_date
        end
      end
    when *BUNDLE_TYPES.keys
      # NOTE As of Feb 2017, creating Bundles through Quickbooks API
      # is not supported. The below method is being kept for future use as it sets
      # up the item in the same structure that we receive from the bundle query.
      # This also allows each part to still sync to QBO
      qbo_item.type = "Group"
      qbo_item.track_quantity_on_hand = false
      # qbo_item.print_grouped_items? = false
      qbo_group_lines = variant_hash[:parts_variants].map do |part_variant|
        qbo_synchronize_variant(part_variant[:part_id], 'Spree::Variant')
        part_match_id = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: part_variant[:part_id]).try(:sync_id)
        qbo_group_line = Quickbooks::Model::ItemGroupLine.new
        qbo_group_line.item_ref = {value: part_match_id}
        qbo_group_line.quantity = part_variant[:quantity]
        qbo_group_line
      end
      qbo_group_detail = Quickbooks::Model::ItemGroupDetail.new(line_items: qbo_group_lines)
      qbo_item.item_group_details = qbo_group_detail
    when *SERVICE_TYPES.keys
      qbo_item.type = "Service"
      qbo_item.track_quantity_on_hand = false
    else
      qbo_item.type = "NonInventory"
      qbo_item.track_quantity_on_hand = false
    end

    income_account = Spree::ChartAccount.find_by_id(variant_hash.fetch(:income_account_id, nil))
    cogs_account = Spree::ChartAccount.find_by_id(variant_hash.fetch(:cogs_account_id, nil))
    expense_account = Spree::ChartAccount.find_by_id(variant_hash.fetch(:expense_account_id, nil))
    asset_account = Spree::ChartAccount.find_by_id(variant_hash.fetch(:asset_account_id, nil))

    if income_account
      qbo_synchronize_chart_account(income_account.id)
      income_match = self.integration_sync_matches.where(
        integration_syncable_id: income_account.id,
        integration_syncable_type: 'Spree::ChartAccount'
      ).first
      qbo_income_account = self.integration_item.qbo_service('Account').fetch_by_id(income_match.try(:sync_id))
      if qbo_income_account
        ref1 = Quickbooks::Model::BaseReference.new(qbo_income_account.try(:id))
        ref1.name = qbo_income_account.try(:name)
        qbo_item.income_account_ref = ref1
      end
    end

    product_hash = variant_hash.fetch(:product, {})
    if product_hash.fetch(:for_sale, false) && income_account.nil? && !variant_hash.fetch(:variant_type) == 'bundle'
      raise Exception.new("An income account must be supplied for sale items.")
    end

    if product_hash.fetch(:for_purchase, false)
      if INVENTORY_TYPES.has_key?(variant_hash.fetch(:variant_type)) && cogs_account.nil?
        raise Exception.new("A cost of goods sold account must be supplied for inventory items.")
      end
      if NON_INVENTORY_NO_BUILD_TYPES.has_key?(variant_hash.fetch(:variant_type)) && cogs_account.nil? && expense_account.nil?
        raise Exception.new("A expense or cost of goods sold account must be supplied for purchase items.")
      end
    end

    if cogs_account
      qbo_synchronize_chart_account(cogs_account.id)
      cogs_match = self.integration_sync_matches.where(
        integration_syncable_id: cogs_account.id,
        integration_syncable_type: 'Spree::ChartAccount'
      ).first
      qbo_cogs_account = self.integration_item.qbo_service('Account').fetch_by_id(cogs_match.try(:sync_id))
      if qbo_cogs_account
        ref1 = Quickbooks::Model::BaseReference.new(qbo_cogs_account.try(:id))
        ref1.name = qbo_cogs_account.try(:name)
        qbo_item.expense_account_ref = ref1
      end
    elsif expense_account
      qbo_synchronize_chart_account(expense_account.id)
      expense_match = self.integration_sync_matches.where(
        integration_syncable_id: expense_account.id,
        integration_syncable_type: 'Spree::ChartAccount'
      ).first
      qbo_expense_account = self.integration_item.qbo_service('Account').fetch_by_id(expense_match.try(:sync_id))
      if qbo_expense_account
        ref1 = Quickbooks::Model::BaseReference.new(qbo_expense_account.try(:id))
        ref1.name = qbo_expense_account.try(:name)
        qbo_item.expense_account_ref = ref1
      end
    end

    if asset_account
      qbo_synchronize_chart_account(asset_account.id)
      asset_match = self.integration_sync_matches.where(
        integration_syncable_id: asset_account.id,
        integration_syncable_type: 'Spree::ChartAccount'
      ).first
      qbo_asset_account = self.integration_item.qbo_service('Account').fetch_by_id(asset_match.try(:sync_id))
      if qbo_asset_account
        ref1 = Quickbooks::Model::BaseReference.new(qbo_asset_account.try(:id))
        ref1.name = qbo_asset_account.try(:name)
        qbo_item.asset_account_ref = ref1
      end
    end

    if variant_hash.fetch(:tax_category_id, nil)
      qbo_tax_code = self.qbo_synchronize_tax_category(variant_hash.fetch(:tax_category_id))
      qbo_item.sales_tax_code_ref = Quickbooks::Model::BaseReference.new(qbo_tax_code.try(:id))
    end

    qbo_item
  end


  def qbo_item_to_product(qbo_item)
    {
      name: qbo_item.sub_item? ? nil : qbo_item.name,
      description: qbo_item.sub_item? ? nil : qbo_item.description,
      available_on: qbo_item.inv_start_date
    }
  end

  def qbo_item_to_variant(qbo_item)
    {
      sku: qbo_item.sku,
      track_inventory: qbo_item.track_quantity_on_hand?
    }
  end

  def qbo_item_to_option_value(qbo_item)
    {
      name: qbo_item.sub_item? ? qbo_item.name : nil
    }
  end

  def qbo_safe_string(string)
    return '' if string.nil?
    string.gsub(/'/, {"'" => "\\'"})
          .gsub(/\R/, "\n")
  end

end
