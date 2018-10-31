class AddDefaultIndexToStockLocation < ActiveRecord::Migration
  def change
    add_index :spree_stock_locations, :default
  end
end
