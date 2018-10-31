class AddVendorToTaxonomy < ActiveRecord::Migration
  def change
    add_column :spree_taxonomies, :vendor_id, :integer
    add_index :spree_taxonomies, :vendor_id
  end
end
