class CreateSpreePriceLists < ActiveRecord::Migration
  def change
    create_table :spree_price_lists do |t|
      t.string :name
      t.integer :vendor_id
      t.integer :customer_type_id
      t.timestamps
    end
    
    add_index :spree_price_lists, :name
    add_index :spree_price_lists, :vendor_id
    add_index :spree_price_lists, :customer_type_id
  end
end
