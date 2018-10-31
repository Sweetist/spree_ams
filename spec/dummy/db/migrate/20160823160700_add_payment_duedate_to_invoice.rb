class AddPaymentDuedateToInvoice < ActiveRecord::Migration
  def change
	  add_column :spree_payment_terms, :num_days, :integer, :default => 0
    add_index :spree_payment_terms, :num_days
  end
end
