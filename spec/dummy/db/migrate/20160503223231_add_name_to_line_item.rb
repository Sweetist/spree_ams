class AddNameToLineItem < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :item_name, :string
  end
end
