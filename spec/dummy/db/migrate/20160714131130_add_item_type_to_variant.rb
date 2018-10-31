class AddItemTypeToVariant < ActiveRecord::Migration
  def change
    add_column :spree_variants, :variant_type, :string
    remove_column :spree_variants, :is_inventory_item
    remove_column :spree_variants, :is_sales_and_purchase
  end
end
