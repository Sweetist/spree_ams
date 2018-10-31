Spree::Stock::Estimator.class_eval do
  def shipping_rates(package, shipping_method_filter = Spree::ShippingMethod::DISPLAY_ON_FRONT_AND_BACK_END)
    rates = calculate_shipping_rates(package, shipping_method_filter)
    choose_default_shipping_rate(rates)
    sort_shipping_rates(rates)
  end

  def calculate_shipping_rates(package, ui_filter)
    shipping_methods(package, ui_filter).map do |shipping_method|
      # Override spree to send to a new method compute_order if there is no package.
      # This is ok when there is only one shipment or there is a package for the shipments
      cost = shipping_method.calculator.compute(package)
      tax_category = shipping_method.tax_category
      if tax_category
        tax_rate = tax_category.tax_rates.detect do |rate|
          # If the rate's zone matches the order's zone, a positive adjustment will be applied.
          # If the rate is from the default tax zone, then a negative adjustment will be applied.
          # See the tests in shipping_rate_spec.rb for an example of this.d
          rate.zone == order.tax_zone || rate.zone.default_tax?
        end
      end

      if cost
        rate = shipping_method.shipping_rates.new(cost: cost)
        rate.tax_rate = tax_rate if tax_rate
      end

      rate
    end.compact
  end

  def shipping_methods(package, display_filter)
    # Override to check for a package, otherwise we select from the vendor's
    # shipping methods and check availability based on address and display on
    if package.present?
      methods = package.shipping_methods
      object = package
    else
      methods = [order.try(:shipping_method)].compact
      object = order
    end
    methods.select do |ship_method|
      calculator = ship_method.calculator
      next if order.shipping_method.try(:calculator) != calculator
      begin
        ship_method.available_to_display(display_filter) &&
          ship_method.include?(order.ship_address) &&
          calculator.available?(object) &&
          (calculator.preferences[:currency].blank? ||
          calculator.preferences[:currency] == currency)
      rescue Exception => exception
        order.shipments.last.update(cost: 0) if order.shipments.present?
        log_calculator_exception(ship_method, exception)
        raise exception
      end
    end
  end
end
