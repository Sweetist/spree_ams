class ChangeShowPartsDefault < ActiveRecord::Migration
  def change
    change_column_default :spree_variants, :show_parts, false
  end
end
