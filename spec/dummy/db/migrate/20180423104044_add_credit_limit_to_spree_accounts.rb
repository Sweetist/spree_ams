class AddCreditLimitToSpreeAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts,
               :credit_limit,
               :decimal, precision: 15, scale: 5, default: 0, null: false
  end
end
