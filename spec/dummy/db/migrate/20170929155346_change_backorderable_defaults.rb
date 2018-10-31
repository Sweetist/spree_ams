class ChangeBackorderableDefaults < ActiveRecord::Migration
  def change
    change_column :spree_stock_locations, :backorderable_default, :boolean, default: true
    change_column :spree_stock_items, :backorderable, :boolean, default: true
  end
end
