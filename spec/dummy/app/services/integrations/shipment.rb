module Integrations
  module Shipment
    # use data with price, tracking_number, tracking_company
    # or this fields in wombat_format(cost, tracking, shipping_method)
    def process_for(order)
      return unless order
      @order = order.reload
      return if @order.refunds.any?

      create_shipment! if (tracking_company_name && finded) || finded.blank?
      override_shipping_cost(shipment_cost)
      override_shipping_tracking(tracking_number)
      handle_taxes
      handle_status if @data['status'].present?
    end

    def spree_object
      update_assign_sync_id(order_from_data)
      process_for(order_from_data)
      @result = "Shipment in order #{@order.display_number} updated."
      @order
    end

    private

    def handle_status
      unless @data['status'] == 'complete'
        @order.trigger_transition
        return
      end

      errors = @order.move_to_shipped
      raise_errors(errors) if errors.any?
    end

    def vendor_object
      return @order.vendor if @order
      order_from_data.vendor
    end

    def order_from_data
      Spree::Order.lock(true).find_by(number: @data['order_id'])
    end

    def tax_data
      { tax_lines: @data['tax_lines'] }
    end

    def handle_taxes
      "#{self.class.parent}::Tax"
        .constantize
        .new(tax_data.merge(parameters: parameters))
        .process_for(@shipment)
    end

    def shipping_category
      return sync_item_shipping_category if sync_item_shipping_category
      vendor_object.shipping_categories.first
    end

    def shipment_cost
      @data[:price] || @data[:cost]
    end

    def tracking_number
      @data[:tracking_number] || @data[:tracking]
    end

    def tracking_company_name
      @data[:tracking_company] || @data[:shipping_method]
    end

    def shipping_method_from_tracking_company
      shipping = shipping_category
                 .shipping_methods
                 .find_or_initialize_by(name: tracking_company_name,
                                        code: tracking_company_name)
      return shipping unless shipping.new_record?
      shipping.zones << sync_item_tax_zone
      shipping.shipping_categories << shipping_category
      shipping.calculator_type = 'Spree::Calculator::Shipping::FlatRate'
      shipping.save!
      shipping
    end

    def shipping_method
      return @shipping_method if @shipping_method
      if tracking_company_name
        return @shipping_method = shipping_method_from_tracking_company
      end
      if sync_item_shipping_method.blank?
        return @shipping_method = @order.set_shipping_method
      end
      @shipping_method = vendor_object.shipping_methods
                                      .find_by(id: sync_item_shipping_method)
    end

    def update_order_shipping_method
      @order.shipping_method_id = shipping_method
      @order.update_column(:shipping_method_id, shipping_method.id)
    end

    def create_shipment!
      update_order_shipping_method
      shipment = @order.shipments
                       .find_or_create_by!(stock_location_id: stock_location_object.id)
      shipment.update_taxes = false

      return unless shipping_method
      shipment.shipping_rates = []
      shipment.add_shipping_method(shipping_method, true)
      shipment.save!
      @shipment = shipment
    end

    def finded
      @shipment = @order.shipments.first
    end

    def override_shipping_cost(shipping_cost)
      return if @order.shipment_total == shipping_cost
      return unless sync_item_overwrite_shipping_cost?
      @order.update_columns(override_shipment_cost: true,
                            shipment_total: shipping_cost.to_d)
      @order.shipments.each do |s|
        s.refresh_rates
        s.update_amounts
      end

      @order.updater.update
    end

    def override_shipping_tracking(tracking_number = nil)
      return unless tracking_number

      @order.update_tracking_number(tracking_number)
    end
  end
end
