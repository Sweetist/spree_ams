class AddInvoiceDateToInvoices < ActiveRecord::Migration
  def change
    add_column :spree_invoices, :invoice_date, :datetime
    add_index  :spree_invoices, :invoice_date
  end
end
