class AddJoinTableBetweenLotAndStockItems < ActiveRecord::Migration
  def change
  	create_table :spree_stock_item_lots do |t|
      t.integer :lot_id, null: false
      t.integer :stock_item_id, null: false
     end
  add_index :spree_stock_item_lots, :stock_item_id
  add_index :spree_stock_item_lots, :lot_id
  end
end
