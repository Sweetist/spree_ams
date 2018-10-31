class CreateSpreePartLots < ActiveRecord::Migration
  def change
    create_table :spree_part_lots do |t|
      t.integer :assembly_lot_id, null: false, index: true
      t.integer :part_lot_id, null: false, index: true
      t.integer :parent_id, null: true, index: true
      t.integer :lft, null: false, index: true
      t.integer :rgt, null: false, index: true
      t.integer :depth, null: false, default: 0
      t.integer :children_count, null: false, default: 0
    end
  end
end
