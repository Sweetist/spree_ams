class AddFullDisplayNameToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :full_display_name, :string
    add_index  :spree_variants, :full_display_name
    change_column :spree_variants, :display_name, :string, default: '', null: false
    add_index  :spree_variants, :display_name
  end
end
