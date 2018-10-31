class AddVendorToZones < ActiveRecord::Migration
  def change
		add_column :spree_zones, :vendor_id, :integer
		add_index :spree_zones, :vendor_id
  end
end
