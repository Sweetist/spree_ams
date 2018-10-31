class AddExternalBalanceToAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :external_balance, :decimal, precision: 15, scale: 5, default: 0, null: false
    add_column :spree_accounts, :external_credit, :decimal, precision: 15, scale: 5, default: 0, null: false

    add_index  :spree_accounts, :external_balance
    add_index  :spree_accounts, :external_credit
    add_index  :spree_accounts, :balance
    add_index  :spree_accounts, :available_credit
  end
end
