class CreateSpreeAssemblyBuilds < ActiveRecord::Migration
  def change
    create_table :spree_assembly_builds do |t|
      t.integer :assembly_id, null: false
      t.integer :quantity, default: 0, null: false

      t.timestamps null: false
    end
    add_index :spree_assembly_builds, :assembly_id
  end
end
