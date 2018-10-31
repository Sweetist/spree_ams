class AddReceivingToLineItems < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :shipped_qty, :integer
    add_column :spree_line_items, :received_qty, :integer
    add_column :spree_line_items, :shipped_total, :decimal
    add_column :spree_line_items, :received_total, :decimal
    add_column :spree_line_items, :confirm_received, :boolean, default: false
  end
end
