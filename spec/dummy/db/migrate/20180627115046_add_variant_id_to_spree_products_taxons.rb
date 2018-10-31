class AddVariantIdToSpreeProductsTaxons < ActiveRecord::Migration
  def change
    add_column :spree_products_taxons, :variant_id, :integer
    add_index :spree_products_taxons, :variant_id
  end
end
