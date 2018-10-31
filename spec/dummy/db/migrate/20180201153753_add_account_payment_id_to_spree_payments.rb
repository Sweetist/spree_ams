class AddAccountPaymentIdToSpreePayments < ActiveRecord::Migration
  def change
    add_column :spree_payments, :account_payment_id, :integer
    add_index :spree_payments, :account_payment_id
  end
end
