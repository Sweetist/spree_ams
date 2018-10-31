class AddDateToCreditMemo < ActiveRecord::Migration
  def up
    add_column :spree_credit_memos, :txn_date, :datetime
    Spree::CreditMemo.find_each do |memo|
      memo.update_columns(txn_date: memo.created_at)
    end
    change_column_null :spree_credit_memos, :txn_date, false
    add_index :spree_credit_memos, :txn_date
  end

  def down
    remove_index :spree_credit_memos, :txn_date
    remove_column :spree_credit_memos, :txn_date
  end
end
