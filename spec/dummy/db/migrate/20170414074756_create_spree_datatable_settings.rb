class CreateSpreeDatatableSettings < ActiveRecord::Migration
  def change
    create_table :spree_datatable_settings do |t|
      t.integer :user_id, index: true, foreign_key: true
      t.string :path_name, null: false
      t.jsonb :state, null: false

      t.timestamps null: false
    end
    add_index :spree_datatable_settings, :path_name
  end
end
