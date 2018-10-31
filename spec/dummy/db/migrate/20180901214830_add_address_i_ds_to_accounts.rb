class AddAddressIDsToAccounts < ActiveRecord::Migration
  def change
		add_column :spree_accounts, :bill_address_id, :integer
		add_column :spree_accounts, :default_ship_address_id, :integer
		add_index :spree_accounts, :bill_address_id
		add_index :spree_accounts, :default_ship_address_id
  end
end
