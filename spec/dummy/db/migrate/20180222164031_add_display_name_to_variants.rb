class AddDisplayNameToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :display_name, :string
    add_column :spree_variants, :full_or_display_name, :string
    add_index  :spree_variants, :full_or_display_name
  end
end
