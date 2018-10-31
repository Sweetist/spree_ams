class AddLotTable < ActiveRecord::Migration
  def change
    create_table :spree_lots do |t|
      t.string :number, null: false
      t.integer :qty_on_hand, null: false, default: 0
      t.integer :qty_sold, null: false, default: 0
      t.integer :qty_waste, null: false, default: 0
      t.datetime :available_at
      t.datetime :expires_at
      t.datetime :sell_by
      
      t.timestamps null: false
    end
    
  add_index :spree_lots, :created_at
  add_index :spree_lots, :available_at
  add_index :spree_lots, :expires_at
  add_index :spree_lots, :sell_by
  add_index :spree_lots, :number
  end
end