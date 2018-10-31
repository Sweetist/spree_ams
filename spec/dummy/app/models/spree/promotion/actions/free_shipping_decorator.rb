Spree::Promotion::Actions::FreeShipping.class_eval do
  include Spree::AdjustmentSource

  def perform(payload={})
    order = payload[:order]
    create_unique_adjustments(order, order.shipments)
  end

  def compute_amount(shipment)
    shipment.cost * -1
  end
end
