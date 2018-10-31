class AddTaxableBooleanToAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :taxable, :boolean, default: false
  end
end
