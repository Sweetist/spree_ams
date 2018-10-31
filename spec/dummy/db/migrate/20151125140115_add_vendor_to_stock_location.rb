class AddVendorToStockLocation < ActiveRecord::Migration
  def change
    add_column :spree_stock_locations, :vendor_id, :integer
    add_index :spree_stock_locations, :vendor_id
  end
end
