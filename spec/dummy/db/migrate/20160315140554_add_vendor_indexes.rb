class AddVendorIndexes < ActiveRecord::Migration
  def change
    add_index :spree_orders, :vendor_id
    add_index :spree_orders, :customer_id
    add_index :spree_orders, [:vendor_id, :number]
    add_index :spree_orders, [:customer_id, :number]
    add_index :spree_orders, [:vendor_id, :delivery_date]
    add_index :spree_orders, [:customer_id, :delivery_date]

    add_index :spree_products, :vendor_id
    add_index :spree_products, [:deleted_at, :vendor_id]

    add_index :spree_variants, [:deleted_at, :is_master, :product_id]
    add_index :spree_variants, [:deleted_at, :product_id]
    add_index :spree_prices, [:deleted_at, :variant_id]

    add_index :spree_promotions, :vendor_id

    add_index :spree_users, :vendor_id
    add_index :spree_users, :customer_id
  end
end
