class AddVendorToOrder < ActiveRecord::Migration
  def change
    add_column :spree_orders, :vendor_id, :integer
    add_column :spree_orders, :customer_id, :integer 
  end
end
