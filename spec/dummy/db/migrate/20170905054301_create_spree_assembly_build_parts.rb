class CreateSpreeAssemblyBuildParts < ActiveRecord::Migration
  def change
    create_table :spree_assembly_build_parts do |t|
      t.integer :build_id
      t.integer :quantity
      t.integer :variant_id
      t.integer :stock_item_lot_id
      t.integer :stock_item_id

      t.timestamps null: false
    end
    add_index :spree_assembly_build_parts, :build_id
    add_index :spree_assembly_build_parts, :variant_id
  end
end
