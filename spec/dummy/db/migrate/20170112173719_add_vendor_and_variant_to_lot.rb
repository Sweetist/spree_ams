class AddVendorAndVariantToLot < ActiveRecord::Migration
  def change
  	add_column :spree_lots, :variant_id, :integer, null: false
    add_index :spree_lots, :variant_id
    add_column :spree_lots, :vendor_id, :integer, null: false
    add_index :spree_lots, :vendor_id
  end
end
