class ChangePackSizeDefaults < ActiveRecord::Migration
  def change
    change_column :spree_variants, :pack_size, :string, default: '', null: false
    change_column :spree_line_items, :pack_size, :string, default: '', null: false
    change_column :spree_standing_line_items, :pack_size, :string, default: '', null: false
  end
end
