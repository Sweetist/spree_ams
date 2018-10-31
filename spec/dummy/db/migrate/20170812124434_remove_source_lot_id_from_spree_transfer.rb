class RemoveSourceLotIdFromSpreeTransfer < ActiveRecord::Migration
  def change
    remove_column :spree_stock_transfers, :source_lot_id, :integer
    remove_column :spree_stock_transfers, :destination_lot_id, :integer
  end
end
