class AddBillAndShipAddressToVendor < ActiveRecord::Migration
  def change
    add_column :spree_vendors, :bill_address_id, :integer
    add_index :spree_vendors, :bill_address_id 
    add_column :spree_vendors, :ship_address_id, :integer
    add_index :spree_vendors, :ship_address_id 
  end
end
