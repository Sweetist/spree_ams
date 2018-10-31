class AddDestinationStockItemLotAndSourceStockItemLotToSpreeStockTransfers < ActiveRecord::Migration
  def change
    add_column :spree_stock_transfers, :source_lot_id, :integer
    add_column :spree_stock_transfers, :destination_lot_id, :integer
    add_column :spree_stock_transfers, :sync, :boolean, default: true
    add_column :spree_stock_transfers, :with_lots, :boolean, default: false
  end
end
