module Integrations
  module Order
    attr_reader :order

    def spree_object
      return @order if @order
      @order = finded
      @order = updated if finded && order_data_exist?
      @order ||= create_new_object

      @order
    end

    private

    def placed_on_date
      placed_on_time.to_date
    end

    def placed_on_time
      Time.parse(placed_on).try(:utc)
    end

    def variant_data_for(_line_item)
      raise Error, I18n.t('integrations.please_implement_in_integration')
    end

    def product_data_for(_line_item)
      raise Error, I18n.t('integrations.please_implement_in_integration')
    end

    def customer_data
      raise Error, I18n.t('integrations.please_implement_in_integration')
    end

    def line_items_data
      return line_items_data_by_product if update_products?
      line_items_data_by_variant
    end

    def line_items_data_by_product
      line_items_data = {}
      line_items.each do |line_item|
        product = "#{self.class.parent}::Product"
                  .constantize.new(product_data_for(line_item))
        variant = product.variant_by(line_item['product_id'])
        no_variant_error_for(line_item('product_id'), line_item('name')) unless variant
        line_items_data[variant.id.to_s] = line_item.dig('quantity')
      end
      line_items_data
    end

    def line_items_data_by_variant
      line_items_data = {}
      line_items.each do |line_item|
        variant = "#{self.class.parent}::Variant"
                  .constantize.new(variant_data_for(line_item)).spree_object
        line_items_data[variant.id.to_s] = line_item.dig('quantity')
      end
      line_items_data
    end

    def assign_or_update_line_items
      errors = order.contents.add_many(line_items_data)
      raise Error, errors if errors.present?
    end

    def order_data_exist?
      data = @data.slice(*Spree::Order.attribute_names).except(:id)
      return true if data.any?
      false
    end

    def customer_account
      return @customer_account if @customer_account
      @customer_account = "#{self.class.parent}::Customer"
                          .constantize.new(customer_data).spree_object
    end

    def update_customer
      order.account = customer_account
      order.customer = customer_account.customer if customer_account
      order.bill_address = customer_account.try(:billing_address)
      order.ship_address = customer_account.try(:default_shipping_address)
      order.save!
    end

    def prepared_adjustments
      adjustments.map do |adjustment|
        next if adjustment.key?('value') && adjustment.dig('value').try(:to_d).try(:zero?)
        adjustment[:label] = adjustment.delete('name') if adjustment.key?('name')
        adjustment[:amount] = adjustment.delete('value') if adjustment.key?('value')
        adjustment
      end
    end

    def create_adjustments_from_params
      return if order.reload.refunds.present?
      order_adjustments = prepared_adjustments.compact
      return [] unless order_adjustments.present?
      order.adjustments = []
      order_adjustments.each do |a|
        adjustment = order.adjustments.build(
          order: order, amount: a[:amount].to_f, label: a[:label]
        )
        adjustment.save!
        adjustment.close!
      end
    end

    def void
      order.void
      save_result(order, 'void')
    end

    def cancel
      return if order.state == 'canceled'
      return void if VoidableStates.include? order.state
      ActiveRecord::Base.transaction do
        order.update_columns(completed_at: Time.current) unless order.completed_at
        order.cancel!
        order.update_columns(
          canceled_at: Time.current
        )
      end
      save_result(order, 'canceled')
    end

    def approve
      return if order.state == 'approved'
      order.update_columns(completed_at: placed_on_time,
                           state: 'complete')
      order.approve
    end

    def fulfill
      approve unless order.state == 'approved'
      order.next
    end

    def handle_status
      return if %w[canceled void].include? order.state

      case status
      when 'fulfilled'
        fulfill
      when 'cancelled'
        cancel
      when 'completed'
        approve
      end
      errors = order.errors.full_messages
      raise Error, errors if errors.present?
    end

    def finded
      return @finded if @finded
      @finded = find_object_by(sync_id: sync_id,
                               sync_type: sync_type,
                               klass: 'Spree::Order')
      @finded ||= try_find_by_number
      @finded
    end

    def try_find_by_number
      return unless respond_to?(:order_number)
      order = vendor_object.sales_orders
                           .where('spree_orders.number LIKE :number',
                                  number: order_number).first
      return unless order
      update_assign_sync_id(order)
      @result = I18n.t('integrations.integration_sync_match_updated',
                       order: order.display_number)
      order
    end

    def order_data
      data = { delivery_date: placed_on_date,
               currency: currency,
               channel: sync_type }
      data[:number] = order_number if respond_to?(:order_number)
      data
    end

    def fulfillment_data
      return fulfillments.first if respond_to?(:fulfillments) \
                                   && fulfillments.present?
      { tracking_company: nil, tracking_number: nil }
    end

    def shipment_data
      return shipping_lines.first if respond_to?(:shipping_lines) \
                                     && shipping_lines.present?
      { price: totals['shipping'] }
    end

    def handle_shippings
      "#{self.class.parent}::Shipment"
        .constantize
        .new(shipment_data.merge(fulfillment_data)
                          .merge(parameters: parameters))
        .process_for(order)
    end

    def tax_data
      { tax_lines: @data['tax_lines'],
        line_items: @data['line_items'] }
    end

    def handle_taxes
      "#{self.class.parent}::Tax"
        .constantize
        .new(tax_data.merge(parameters: parameters))
        .process_for_order(order)
    end

    def handle_inventory_refunds
      # Please override method if integration support refunds
      nil
    end

    def remove_blank_shipments
      for_del = order.shipments.select { |sh| sh.cost.zero? }
      for_del.map(&:destroy) if for_del.any?
    end

    def handle_payment_transactions
      "#{self.class.parent}::Payment"
        .constantize.new({ order_shopify_id: @data['shopify_id'] }
                    .merge(parameters: parameters))
        .process_for(order)
    end

    # shared functions for created and finded order
    def process_shared
      handle_taxes
      handle_shippings
      create_adjustments_from_params
      handle_status
      handle_inventory_refunds
      handle_payment_transactions
      order.updater.update
    end

    def create_new_object
      critical_data_not_found unless order_data_exist?
      ActiveRecord::Base.transaction do
        @order = vendor_object.sales_orders.new(order_data)
        update_customer
        order.state = 'complete'
        order.email = order.account.try(:email)
        order.save!
        create_assign_sync_id(order)
        assign_or_update_line_items
        remove_blank_shipments
        process_shared
        save_result(order, 'created')
        order
      end
    end

    def updated
      ActiveRecord::Base.transaction do
        update_assign_sync_id(order)
        order.update(order_data)
        update_customer
        process_shared
        save_result(order, 'updated')
        order.reload
      end
    end
  end
end
