class AddIndexAndRecalculateToAccountViewableProducts < ActiveRecord::Migration
  def change
    add_column :spree_account_viewable_products, :recalculating, :boolean
    add_index :spree_account_viewable_products, [:product_id, :account_id], name: :viewable_products_on_product_id_and_account_id
  end
end
