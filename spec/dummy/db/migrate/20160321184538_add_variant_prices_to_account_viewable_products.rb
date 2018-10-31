class AddVariantPricesToAccountViewableProducts < ActiveRecord::Migration
  def change
    add_column :spree_account_viewable_products, :variants_prices, :json
    add_index :spree_account_viewable_products, :recalculating
  end
end
