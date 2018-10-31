class AddPositionToSpreeStandingLineItems < ActiveRecord::Migration
  def change
    add_column :spree_standing_line_items, :position, :integer
  end
end
