class AddPackSizeToLineItem < ActiveRecord::Migration
  def up
    add_column :spree_line_items, :pack_size, :string
    add_column :spree_standing_line_items, :pack_size, :string
    add_column :spree_standing_line_items, :lot_number, :string
    add_index :spree_line_items, :pack_size
    add_index :spree_standing_line_items, :pack_size
    add_index :spree_standing_line_items, :lot_number
  end

  def down
    remove_index :spree_line_items, :pack_size
    remove_index :spree_standing_line_items, :pack_size
    remove_index :spree_standing_line_items, :lot_number
    remove_column :spree_line_items, :pack_size, :string
    remove_column :spree_standing_line_items, :pack_size, :string
    remove_column :spree_standing_line_items, :lot_number, :string
  end
end
