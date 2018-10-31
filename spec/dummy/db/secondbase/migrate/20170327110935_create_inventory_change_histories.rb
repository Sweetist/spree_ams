class CreateInventoryChangeHistories < ActiveRecord::Migration
  def change
    create_table :inventory_change_histories do |t|
      t.integer   :stock_item_id,           null: false
      t.integer   :stock_location_id,       null: false
      t.integer   :user_id
      t.integer   :company_id
      t.integer   :variant_id,              null: false
      t.string    :action,                  null: false
      t.integer   :customer_id
      t.string    :reason

      t.integer   :customer_type_id
      t.string    :pack_size

      t.decimal   :quantity,                scale: 2, precision: 8, null: false
      t.decimal   :quantity_on_hand,        scale: 2, precision: 8, null: false

      t.integer   :originator_id,           null: false
      t.string    :originator_type,         null: false
      t.datetime  :originator_created_at,   null: false
      t.datetime  :originator_updated_at
      t.string    :originator_number,       null: false

      t.string    :item_variant_name,       null: false
      t.string    :item_variant_sku,        null: false
      t.string    :stock_location_name,     null: false
      t.string    :customer_name
      t.string    :customer_type_name

      t.integer   :source_location_id
      t.string    :source_location_name

      t.timestamps null: false
    end
  end
end
