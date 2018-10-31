class AddVendorToOptionValues < ActiveRecord::Migration
  def change
    add_column :spree_option_values, :vendor_id, :integer
    add_index :spree_option_values, :vendor_id
  end
end
