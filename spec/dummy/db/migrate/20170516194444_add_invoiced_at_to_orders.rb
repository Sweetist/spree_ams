class AddInvoicedAtToOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :invoiced_at, :datetime
    add_index :spree_orders, :invoiced_at
  end
end
