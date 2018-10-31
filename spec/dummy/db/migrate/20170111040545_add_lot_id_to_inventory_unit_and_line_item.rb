class AddLotIdToInventoryUnitAndLineItem < ActiveRecord::Migration
  def change
  	add_column :spree_line_items, :lot_id, :integer
    add_index :spree_line_items, :lot_id
    add_column :spree_inventory_units, :lot_id, :integer
    add_index :spree_inventory_units, :lot_id
  end
end
