class AddProceedToImports < ActiveRecord::Migration
  def change
    add_column :spree_product_imports, :proceed, :boolean
    add_column :spree_customer_imports, :proceed, :boolean
  end
end
