class AddShipAddresstoCustomers < ActiveRecord::Migration
  def change
		add_column :spree_customers, :ship_address_id, :integer
		add_index :spree_customers, :ship_address_id
  end
end
