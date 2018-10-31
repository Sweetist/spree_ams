class AddLastIpAddressToAccountPayments < ActiveRecord::Migration
  def change
    add_column :spree_account_payments, :last_ip_address, :string
  end
end
