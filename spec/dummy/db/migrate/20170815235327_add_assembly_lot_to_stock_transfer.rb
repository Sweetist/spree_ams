class AddAssemblyLotToStockTransfer < ActiveRecord::Migration
  def change
    add_column :spree_stock_transfers, :assembly_lot_id, :integer
    add_index :spree_stock_transfers, :assembly_lot_id
  end
end
