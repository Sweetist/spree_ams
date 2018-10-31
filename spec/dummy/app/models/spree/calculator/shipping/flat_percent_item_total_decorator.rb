Spree::Calculator::Shipping::FlatPercentItemTotal.class_eval do
  # Add this for when there is no package, ie. no inventory_units
  # This is only relevenat when there is only one shipment
  def compute_order(order)
    compute_from_price(order.item_total)
  end
end
