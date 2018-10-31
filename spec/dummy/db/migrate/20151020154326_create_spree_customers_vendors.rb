class CreateSpreeCustomersVendors < ActiveRecord::Migration
  def change
    create_table :spree_customers_vendors do |t|
      t.integer :customer_id
      t.integer :vendor_id

      t.timestamps
    end

    add_index :spree_customers_vendors, :customer_id
    add_index :spree_customers_vendors, :vendor_id
  end
end
