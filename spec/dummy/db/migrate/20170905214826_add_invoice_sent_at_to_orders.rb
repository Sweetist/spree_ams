class AddInvoiceSentAtToOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :invoice_sent_at, :datetime
    add_index  :spree_orders, :invoice_sent_at
  end
end
