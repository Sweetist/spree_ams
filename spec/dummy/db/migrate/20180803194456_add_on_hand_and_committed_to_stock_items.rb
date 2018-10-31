class AddOnHandAndCommittedToStockItems < ActiveRecord::Migration
  def change
    add_column :spree_stock_items, :on_hand, :decimal, precision: 15, scale: 5, default: 0, null: false
    add_column :spree_stock_items, :committed, :decimal, precision: 15, scale: 5, default: 0, null: false
    add_index  :spree_stock_items, :on_hand
    add_index  :spree_stock_items, :committed
  end
end
