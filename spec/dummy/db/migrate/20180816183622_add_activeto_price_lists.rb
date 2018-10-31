class AddActivetoPriceLists < ActiveRecord::Migration
  def change
    add_column :spree_price_lists, :active, :boolean, default: false, null: false
    add_index  :spree_price_lists, :active
  end
end
