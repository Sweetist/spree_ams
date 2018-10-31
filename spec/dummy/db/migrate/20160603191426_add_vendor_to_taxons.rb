class AddVendorToTaxons < ActiveRecord::Migration
  def change
    add_column :spree_taxons, :vendor_id, :integer
    add_index :spree_taxons, :vendor_id
  end
end
