class AddDueBeforeSubmitToPaymentTerm < ActiveRecord::Migration
  def change
    add_column :spree_payment_terms, :pay_before_submit, :boolean, null: false, default: false
    add_index  :spree_payment_terms, :pay_before_submit
  end
end
