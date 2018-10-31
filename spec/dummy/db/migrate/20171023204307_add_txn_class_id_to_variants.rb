class AddTxnClassIdToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :txn_class_id, :integer
    add_index  :spree_variants, :txn_class_id
  end
end
