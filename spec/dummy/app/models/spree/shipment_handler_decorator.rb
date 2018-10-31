Spree::ShipmentHandler.class_eval do
  def perform
    @shipment.inventory_units
             .each { |unit| unit.ship! unless unit.state == 'shipped' }
    send_shipped_email # if @shipment.order.vendor.receive_orders
    @shipment.touch :shipped_at
    # update_order_shipment_state
  end
end
