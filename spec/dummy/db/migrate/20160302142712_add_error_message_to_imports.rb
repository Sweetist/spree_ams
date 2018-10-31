class AddErrorMessageToImports < ActiveRecord::Migration
  def change
    add_column :spree_customer_imports, :exception_message, :text
    add_column :spree_product_imports, :exception_message, :text
  end
end
