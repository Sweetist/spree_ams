class AddAccountToStockTransfer < ActiveRecord::Migration
  def change
    add_column :spree_stock_transfers, :general_account_id, :integer
  end
end
