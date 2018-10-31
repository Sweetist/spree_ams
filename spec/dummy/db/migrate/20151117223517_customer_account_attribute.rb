class CustomerAccountAttribute < ActiveRecord::Migration
  def change
    remove_index :spree_customers, column: :account_id
    remove_column :spree_customers, :account_id
    add_column :spree_customers, :spree_account_id, :string
  end
end
