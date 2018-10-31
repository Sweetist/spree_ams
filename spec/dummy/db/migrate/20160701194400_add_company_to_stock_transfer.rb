class AddCompanyToStockTransfer < ActiveRecord::Migration
  def change
    add_column  :spree_stock_transfers, :company_id, :integer
    add_index   :spree_stock_transfers, :company_id
  end
end
