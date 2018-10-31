class AddVendorToShippingCategory < ActiveRecord::Migration
  def change
    add_column :spree_shipping_categories, :vendor_id, :integer
    add_index :spree_shipping_categories, :vendor_id
  end
end
