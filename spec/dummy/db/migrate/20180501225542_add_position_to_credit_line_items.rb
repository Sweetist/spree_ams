class AddPositionToCreditLineItems < ActiveRecord::Migration
  def change
    add_column :spree_credit_line_items, :position, :integer, default: 0, null: false
    add_index  :spree_credit_line_items, :position
  end
end
