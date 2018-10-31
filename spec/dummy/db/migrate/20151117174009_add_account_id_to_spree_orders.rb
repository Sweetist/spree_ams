class AddAccountIdToSpreeOrders < ActiveRecord::Migration
  def change
    add_column  :spree_orders, :account_id, :integer
    add_index   :spree_orders, :account_id
  end
end
