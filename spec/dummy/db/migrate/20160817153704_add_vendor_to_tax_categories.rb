class AddVendorToTaxCategories < ActiveRecord::Migration
  def change
  	 add_column :spree_tax_categories, :vendor_id, :integer
  	 add_index :spree_tax_categories, :vendor_id
  end
end
