class AddDueDateToInvoice < ActiveRecord::Migration
  def change
	add_column :spree_invoices, :due_date, :datetime
    add_index :spree_invoices, :due_date
  end
end
