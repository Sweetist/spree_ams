class AddAccountNumberToAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :number, :string
  end
end
