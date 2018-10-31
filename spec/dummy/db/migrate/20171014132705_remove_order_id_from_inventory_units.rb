class RemoveOrderIdFromInventoryUnits < ActiveRecord::Migration
  # Removing this migration because it causes lots of problems with returns

  # def up
  #   remove_column :spree_inventory_units, :order_id
  # end
  # def down
  #   add_column :spree_inventory_units, :order_id, :integer
  #   Spree::Shipment.find_each do |s|
  #     s.inventory_units.update_all(order_id: s.order_id)
  #   end
  # end
end
