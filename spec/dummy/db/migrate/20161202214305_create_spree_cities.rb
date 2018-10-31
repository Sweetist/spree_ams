class CreateSpreeCities < ActiveRecord::Migration
  def change
    create_table :spree_cities do |t|
      t.string :name
      t.integer :state_id

      t.timestamps
    end

    add_index :spree_cities, :state_id
  end
end
