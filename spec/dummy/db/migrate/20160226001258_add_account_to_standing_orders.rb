class AddAccountToStandingOrders < ActiveRecord::Migration
  def change
    add_column :spree_standing_orders, :account_id, :integer
    add_index :spree_standing_orders, :account_id
  end
end
