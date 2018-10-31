class AddDisplayNameToCustomerImport < ActiveRecord::Migration
  def change
    add_column :spree_customer_imports, :display_name, :string
  end
end
