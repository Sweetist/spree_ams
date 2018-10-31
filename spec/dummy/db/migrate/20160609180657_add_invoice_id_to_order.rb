class AddInvoiceIdToOrder < ActiveRecord::Migration
  def change
    add_column :spree_orders, :invoice_id, :integer
    add_index :spree_orders, :invoice_id
  end

end
