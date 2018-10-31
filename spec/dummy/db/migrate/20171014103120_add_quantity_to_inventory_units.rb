class AddQuantityToInventoryUnits < ActiveRecord::Migration
  def up
    add_column :spree_inventory_units, :quantity, :integer
    execute 'UPDATE spree_inventory_units SET quantity = 1'
  end
  def down
    remove_column :spree_inventory_units, :quantity, :integer
  end
end
