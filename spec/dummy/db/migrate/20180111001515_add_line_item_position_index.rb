class AddLineItemPositionIndex < ActiveRecord::Migration
  def change
    add_index :spree_line_items, :position
    add_index :spree_standing_line_items, :position
  end
end
