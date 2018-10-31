class CreateSpreeProductsSpreeInventoryItemJoinTable < ActiveRecord::Migration
  def change
    create_table :spree_product_integration_items do |t|
      t.integer :product_id, null: false
      t.integer :item_id, null: false
    end
    add_index :spree_product_integration_items, :product_id
    add_index :spree_product_integration_items, :item_id
  end
end
