class AddVisibleToAllToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :visible_to_all, :boolean, default: false, null: false
  end
end
