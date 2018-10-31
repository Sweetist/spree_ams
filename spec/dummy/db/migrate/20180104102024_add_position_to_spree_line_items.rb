class AddPositionToSpreeLineItems < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :position, :integer
  end
end
