class AddDefaultTxnClassIdToSpreeAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :default_txn_class_id, :integer
    add_index  :spree_accounts, :default_txn_class_id
  end
end
