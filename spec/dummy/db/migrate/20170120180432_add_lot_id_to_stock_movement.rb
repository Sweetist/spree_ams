class AddLotIdToStockMovement < ActiveRecord::Migration
  def change
  	add_column :spree_stock_movements, :lot_id, :integer
    add_index :spree_stock_movements, :lot_id
  end
end
