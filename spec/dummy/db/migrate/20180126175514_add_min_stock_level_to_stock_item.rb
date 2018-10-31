class AddMinStockLevelToStockItem < ActiveRecord::Migration
  def change
    add_column :spree_stock_items, :min_stock_level, :decimal
    add_index :spree_stock_items, :min_stock_level
  end
end
