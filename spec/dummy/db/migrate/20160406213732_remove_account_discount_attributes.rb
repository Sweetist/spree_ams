class RemoveAccountDiscountAttributes < ActiveRecord::Migration
  def change
    remove_column :spree_accounts, :discount
    remove_column :spree_accounts, :cost_price_discount
    remove_column :spree_accounts, :discount_type
  end
end
