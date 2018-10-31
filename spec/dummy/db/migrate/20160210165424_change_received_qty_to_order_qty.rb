class ChangeReceivedQtyToOrderQty < ActiveRecord::Migration
  def change
    rename_column :spree_line_items, :received_qty, :ordered_qty
    rename_column :spree_line_items, :received_total, :ordered_total
  end
end
