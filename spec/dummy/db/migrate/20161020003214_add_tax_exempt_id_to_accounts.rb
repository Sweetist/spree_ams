class AddTaxExemptIdToAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :tax_exempt_id, :string
    add_index :spree_accounts, :tax_exempt_id
  end
end
