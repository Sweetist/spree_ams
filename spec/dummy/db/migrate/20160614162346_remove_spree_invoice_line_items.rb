class RemoveSpreeInvoiceLineItems < ActiveRecord::Migration
  def change
    drop_table :spree_invoice_line_items
  end
end
