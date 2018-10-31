class CreateSpreeCustomerViewableAttributes < ActiveRecord::Migration
  def change
    create_table :spree_customer_viewable_attributes do |t|
      t.integer :vendor_id, null: false
      t.jsonb   :product
      t.jsonb   :variant
      t.jsonb   :line_item
      t.jsonb   :order
      t.jsonb   :invoice
      t.jsonb   :account
      t.jsonb   :payment
      t.jsonb   :standing_line_item
      t.jsonb   :standing_order
    end

    add_index :spree_customer_viewable_attributes, :vendor_id
  end
end
