Spree::Calculator::Shipping::FlexiRate.class_eval do
  # Add this for when there is no package, ie. no inventory_units
  # This is only relevenat when there is only one shipment
  def compute_order(order)
    compute_from_quantity(order.item_count)
  end

  def compute_from_quantity(quantity)
    sum = 0
    max = self.preferred_max_items.to_i
    quantity.to_i.times do |i|
      # check max value to avoid divide by 0 errors
      if (max == 0 && i == 0) || (max > 0) && (i % max == 0)
        sum += self.preferred_first_item.to_f
      else
        sum += self.preferred_additional_item.to_f
      end
    end

    sum
  end
end
