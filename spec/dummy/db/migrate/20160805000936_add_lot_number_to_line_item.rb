class AddLotNumberToLineItem < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :lot_number, :string
    add_index :spree_line_items, :lot_number
  end
end
