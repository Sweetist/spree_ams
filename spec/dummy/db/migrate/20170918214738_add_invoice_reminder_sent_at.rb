class AddInvoiceReminderSentAt < ActiveRecord::Migration
  def change
    add_column :spree_invoices, :reminder_sent_at, :datetime
    add_column :spree_invoices, :past_due_sent_at, :datetime
    add_index  :spree_invoices, :reminder_sent_at
    add_index  :spree_invoices, :past_due_sent_at
  end
end
