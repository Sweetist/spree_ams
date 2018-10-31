class AddAddressesToAccounts < ActiveRecord::Migration
  def change
  	add_column :spree_addresses, :account_id, :integer
	add_column :spree_addresses, :addr_type, :string
	add_index :spree_addresses, :account_id
	add_index :spree_addresses, :addr_type
  end
end
