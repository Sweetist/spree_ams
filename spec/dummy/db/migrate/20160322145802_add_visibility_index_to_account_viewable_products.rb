class AddVisibilityIndexToAccountViewableProducts < ActiveRecord::Migration
  def change
    add_index :spree_account_viewable_products, :visible
  end
end
