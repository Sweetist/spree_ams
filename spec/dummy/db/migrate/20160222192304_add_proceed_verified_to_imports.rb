class AddProceedVerifiedToImports < ActiveRecord::Migration
  def change
    add_column :spree_product_imports, :proceed_verified, :boolean
    add_column :spree_customer_imports, :proceed_verified, :boolean
  end
end
