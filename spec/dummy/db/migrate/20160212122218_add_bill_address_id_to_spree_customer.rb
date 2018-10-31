class AddBillAddressIdToSpreeCustomer < ActiveRecord::Migration
  def change
    add_column :spree_customers, :bill_address_id, :integer
  end
end
