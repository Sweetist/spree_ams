class AddVariantDescriptionToSpreeVariant < ActiveRecord::Migration
  def change
    add_column :spree_variants, :variant_description, :text
  end
end
