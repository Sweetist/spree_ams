class AddCustomerToInvoice < ActiveRecord::Migration
  def up
    add_column  :spree_invoices, :customer_id, :integer
    add_index   :spree_invoices, :customer_id
    Spree::Invoice.find_each{|invoice| invoice.update_columns(customer_id: invoice.account.try(:customer_id))}
  end

  def down
    remove_column :spree_invoices, :customer_id, :integer
  end
end
