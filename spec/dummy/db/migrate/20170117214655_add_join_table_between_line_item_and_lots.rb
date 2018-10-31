class AddJoinTableBetweenLineItemAndLots < ActiveRecord::Migration
  def change
  	create_table :spree_line_item_lots do |t|
      t.integer :lot_id, null: false
      t.integer :line_item_id, null: false
      t.integer :count, null: false, default: 0
    end
	  add_index :spree_line_item_lots, :line_item_id
	  add_index :spree_line_item_lots, :lot_id
  end
end
