class CreateSpreeReps < ActiveRecord::Migration
  def change
    create_table :spree_reps do |t|
      t.string :name, null: false
      t.integer :vendor_id, null: false
      t.timestamps null: false
    end

    add_index :spree_reps, :vendor_id
    add_column :spree_accounts, :rep_id, :integer
    add_index :spree_accounts, :rep_id
  end
end
