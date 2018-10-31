Spree::Calculator::Shipping::FlatRate.class_eval do
  # Add this for when there is no package, ie. no inventory_units
  # This is only relevenat when there is only one shipment
  # this is same as compute_package method
  def compute_order(order)
    self.preferred_amount
  end
end
