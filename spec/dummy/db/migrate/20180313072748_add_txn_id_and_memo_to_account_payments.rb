class AddTxnIdAndMemoToAccountPayments < ActiveRecord::Migration
  def change
    add_column :spree_account_payments, :memo, :text
    add_column :spree_account_payments, :txn_id, :string
  end
end
