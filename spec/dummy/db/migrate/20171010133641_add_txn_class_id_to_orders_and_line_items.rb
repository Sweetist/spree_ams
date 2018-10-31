class AddTxnClassIdToOrdersAndLineItems < ActiveRecord::Migration
  def change
    add_column :spree_orders, :txn_class_id, :integer
    add_index  :spree_orders, :txn_class_id
    add_column :spree_line_items, :txn_class_id, :integer
    add_index  :spree_line_items, :txn_class_id
    add_column :spree_standing_orders, :txn_class_id, :integer
    add_index  :spree_standing_orders, :txn_class_id
    add_column :spree_standing_line_items, :txn_class_id, :integer
    add_index  :spree_standing_line_items, :txn_class_id
    add_index  :spree_transaction_classes, :parent_id
    add_index  :spree_transaction_classes, :vendor_id
  end
end
