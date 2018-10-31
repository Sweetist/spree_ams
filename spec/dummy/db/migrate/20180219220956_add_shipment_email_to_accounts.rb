class AddShipmentEmailToAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :shipment_email, :string
  end
end
