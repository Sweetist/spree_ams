class CreateSpreeCustomerType < ActiveRecord::Migration
  def change
    create_table :spree_customer_types do |t|
      t.string :name, null: false
      t.integer :vendor_id, null: false
    end

    add_index :spree_customer_types, :vendor_id
    add_column :spree_accounts, :customer_type_id, :integer
    add_index :spree_accounts, :customer_type_id
  end
end
