class AddTransferTypeToSpreeStockTransfer < ActiveRecord::Migration
  def change
  	add_column :spree_stock_transfers, :transfer_type, :string
  	add_index :spree_stock_transfers, :transfer_type
  end
end
