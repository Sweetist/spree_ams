class AddMarkPaidToPaymentMethods < ActiveRecord::Migration
  def change
    add_column :spree_payment_methods, :mark_paid, :boolean, default: false, null: false
    add_index  :spree_payment_methods, :mark_paid
  end
end
