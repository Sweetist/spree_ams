class ChangeOrderDateToInvoiceDate < ActiveRecord::Migration
  def change
    remove_index :spree_orders, :order_date
    rename_column :spree_orders, :order_date, :invoice_date
    add_index :spree_orders, :invoice_date
  end
end
