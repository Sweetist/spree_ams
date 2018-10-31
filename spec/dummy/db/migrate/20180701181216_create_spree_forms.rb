class CreateSpreeForms < ActiveRecord::Migration
  def change
    create_table :spree_forms do |t|
      t.string :form_type, null: false
      t.integer :vendor_id, null: false
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.integer :num_columns, default: 1, null: false
      t.string :title
      t.text :instructions
      t.string :submit_text
      t.timestamps
    end

    add_index :spree_forms, :vendor_id
    add_index :spree_forms, :active
    add_index :spree_forms, :name
  end
end
