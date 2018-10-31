class AddShowPartsToSpreeVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :show_parts, :boolean, default: true, null: false
  end
end
