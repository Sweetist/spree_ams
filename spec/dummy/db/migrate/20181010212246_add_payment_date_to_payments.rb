class AddPaymentDateToPayments < ActiveRecord::Migration
  def change
    add_column :spree_account_payments, :payment_date, :datetime
    add_index  :spree_account_payments, :payment_date 
  end
end
