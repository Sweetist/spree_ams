class ChangeLastDeliveryToLastInvoice < ActiveRecord::Migration
  def change
    rename_column :spree_accounts, :last_delivery_date, :last_invoice_date
  end
end
