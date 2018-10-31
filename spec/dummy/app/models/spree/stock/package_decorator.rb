Spree::Stock::Package.class_eval do
  def to_shipment
    shipment = Spree::Shipment.new
    shipment.address = order.ship_address
    shipment.order = order
    shipment.stock_location = stock_location
    shipment.shipping_rates = shipping_rates

    contents.each do |item|
      unit = shipment.inventory_units.build
      unit.pending = true
      unit.variant = item.variant
      unit.line_item = item.line_item
      unit.state = item.state.to_s
      unit.quantity = item.quantity
    end

    shipment
  end
end
