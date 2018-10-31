class AddAccountPaymentIdToSpreeRefunds < ActiveRecord::Migration
  def change
    add_column :spree_refunds, :account_payment_id, :integer
    add_index :spree_refunds, :account_payment_id
  end
end
