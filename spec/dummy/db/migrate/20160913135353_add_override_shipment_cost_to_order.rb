class AddOverrideShipmentCostToOrder < ActiveRecord::Migration
  def change
    add_column :spree_orders, :override_shipment_cost, :boolean, default: false
  end
end
