class AddPriceRangeToAccountViewableProducts < ActiveRecord::Migration
  def change
    add_column :spree_account_viewable_products, :max_price, :decimal, precision: 10, scale: 2
    add_column :spree_account_viewable_products, :min_price, :decimal, precision: 10, scale: 2
    add_column :spree_account_viewable_products, :visible, :boolean, default: false
  end
end
