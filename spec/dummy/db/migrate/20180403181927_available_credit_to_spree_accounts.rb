class AvailableCreditToSpreeAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :available_credit, :decimal, precision: 15, scale: 5, default: 0
    add_column :spree_account_payments, :credit_amount, :decimal, precision: 15, scale: 5, default: 0
    add_column :spree_account_payments, :credit_used, :decimal, precision: 15, scale: 5, default: 0
  end
end
