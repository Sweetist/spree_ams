class CreateStandingLineItems < ActiveRecord::Migration
  def change
    create_table  :spree_standing_line_items do |t|
      t.references :variant
      t.references :standing_order
      t.integer    :quantity
      t.decimal    :price
      t.string     :currency
      t.timestamps null: false
    end

    add_index :spree_standing_line_items, :variant_id
    add_index :spree_standing_line_items, :standing_order_id
  end
end
