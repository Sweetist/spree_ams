Spree::Calculator::Shipping::PerItem.class_eval do
  # Add this for when there is no package, ie. no inventory_units
  # This is only relevenat when there is only one shipment
  def compute_order(order)
    compute_from_quantity(order.item_count)
  end

  def compute_from_quantity(quantity)
    self.preferred_amount ? self.preferred_amount.to_d * quantity : 0
  end
end
