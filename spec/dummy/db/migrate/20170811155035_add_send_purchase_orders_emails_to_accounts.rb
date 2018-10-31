class AddSendPurchaseOrdersEmailsToAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :send_purchase_orders_emails, :boolean, default: false
  end
end
