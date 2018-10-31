class AddProductType < ActiveRecord::Migration
  def change
    add_column :spree_products, :product_type, :string
    add_column :spree_products, :income_account_id, :integer
    add_column :spree_products, :expense_account_id, :integer
    add_column :spree_products, :cogs_account_id, :integer
    add_column :spree_products, :asset_account_id, :integer
    add_column :spree_products, :for_sale, :boolean, default: true, null: false
    add_column :spree_products, :for_purchase, :boolean, default: false, null: false
    add_index :spree_products, :product_type
    add_index :spree_products, :for_sale
    add_index :spree_products, :for_purchase
  end
end
