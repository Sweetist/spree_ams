class CreateSpreeAccountViewableProducts < ActiveRecord::Migration
  def change
    create_table :spree_account_viewable_products do |t|
      t.integer :account_id, null: false
      t.integer :product_id, null: false
    end

    add_index :spree_account_viewable_products, :account_id
    add_index :spree_account_viewable_products, :product_id
  end
end
