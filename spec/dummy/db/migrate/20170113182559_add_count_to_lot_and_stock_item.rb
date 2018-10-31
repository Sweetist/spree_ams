class AddCountToLotAndStockItem < ActiveRecord::Migration
  def change
  	add_column :spree_stock_item_lots, :count, :integer, null: false, default: 0
  	add_index :spree_stock_item_lots, :count
  end
end
