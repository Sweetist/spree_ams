class AddVariantPartIdToSpreeLineItemLots < ActiveRecord::Migration
  def change
    add_column :spree_line_item_lots, :variant_part_id, :integer
  end
end
