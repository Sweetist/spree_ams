class AddDetailsToOrderedParts < ActiveRecord::Migration
  def change
    create_table :spree_ordered_parts do |t|
      t.integer  :part_variant_id, null: false
      t.integer  :line_item_id, null: false, index: true
      t.integer  :quantity, null: false
      t.integer  :part_qty, null: false

      t.timestamps null: false
    end
  end
end
