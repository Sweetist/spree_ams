class CreateSpreeVariantVendors < ActiveRecord::Migration
  def change
    create_table :spree_variant_vendors do |t|
      t.integer :account_id
      t.integer :variant_id
      t.decimal :price, precision: 10, scale: 2, default: 0, null: false
      t.string  :sku
      t.string  :name
      t.timestamps
    end

    add_index :spree_variant_vendors, :account_id
    add_index :spree_variant_vendors, :variant_id
    add_index :spree_variant_vendors, :name
  end
end
