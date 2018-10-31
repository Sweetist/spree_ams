class AddUpdateTaxesToSpreeShipments < ActiveRecord::Migration
  def change
    add_column :spree_shipments, :update_taxes, :boolean, default: true
  end
end
