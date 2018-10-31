class AddTxnIdAndMemoToPayments < ActiveRecord::Migration
  def change
    add_column :spree_payments, :memo, :text
    add_column :spree_payments, :txn_id, :string
  end
end
