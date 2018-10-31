Spree::Calculator::Shipping::PriceSack.class_eval do
  # Add this for when there is no package, ie. no inventory_units
  # This is only relevenat when there is only one shipment
  def compute_order(order)
    compute_from_price(order.item_total)
  end

  def compute_from_price(price)
    if price < self.preferred_minimal_amount.to_d
      self.preferred_normal_amount.to_d
    else
      self.preferred_discount_amount.to_d
    end
  end
end
