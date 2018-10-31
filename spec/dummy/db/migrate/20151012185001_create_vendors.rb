class CreateVendors < ActiveRecord::Migration
  def change
    create_table :vendors do |t|
      t.string :name, null: false
      t.datetime :order_cutoff_time, null: false
      t.decimal :delivery_minimum,  default: 0
      t.integer :payment_terms
      t.timestamps null: false
    end
  end
end
