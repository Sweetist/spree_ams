class CreateCustomers < ActiveRecord::Migration
  def change
    create_table :customers do |t|
      t.string :name, null: false
      t.integer :account_id, null: false
      t.timestamps null: false
    end

    add_index(:customers, :account_id)
  end
end
