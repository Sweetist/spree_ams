class AddPrimaryContactIdAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :primary_cust_contact_id, :integer
    add_column :spree_accounts, :primary_vendor_contact_id, :integer
  end
end
