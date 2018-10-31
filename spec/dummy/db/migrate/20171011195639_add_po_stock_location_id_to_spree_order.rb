class AddPoStockLocationIdToSpreeOrder < ActiveRecord::Migration
  def change
    add_column :spree_orders, :po_stock_location_id, :integer, index: true
  end
end
