class RemoveLotIdInLineItem < ActiveRecord::Migration
  def change
  	remove_column :spree_line_items, :lot_id, :integer
  end
end
