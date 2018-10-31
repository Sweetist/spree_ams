class AddNotesToStockTransfers < ActiveRecord::Migration
  def change
    add_column :spree_stock_transfers, :note, :text
  end
end
