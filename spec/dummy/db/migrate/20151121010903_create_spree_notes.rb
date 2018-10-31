class CreateSpreeNotes < ActiveRecord::Migration
  def change
    create_table :spree_notes do |t|
      t.text :body
      t.integer :user_id, null: false
      t.integer :order_id

      t.timestamps
    end
    add_index :spree_notes, :user_id
    add_index :spree_notes, :order_id
  end
end
