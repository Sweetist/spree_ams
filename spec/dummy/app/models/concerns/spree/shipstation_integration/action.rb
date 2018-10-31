module Spree::ShipstationIntegration::Action
  extend ActiveSupport::Concern

  attr_accessor :shipstation_response_xml

  def shipstation_trigger(integrationable_id, integrationable_type, integration_action)
    self.update_columns(status: 1)
    case integrationable_type
    when 'Spree::Order'
      self.shipstation_synchronize_orders(integration_action)
    when 'Spree::Shipment'
      self.shipstation_synchronize_shipment(integrationable_id, integration_action)
    else
      { status: -1, log: 'Unknown Integrationable Type' }
    end
  end

  def shipstation_synchronize_orders(integration_action)
    { status: 5, log: 'Order Sync from ShipStation' }
  end

  def shipstation_synchronize_shipment(shipment_id, integration_action)
    { status: 5, log: 'ShipStation pushing shipping charges' }
  end

end
