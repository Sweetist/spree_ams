class ChangeTablesToSpreeModuleTables < ActiveRecord::Migration
  def change
		rename_table :vendors, :spree_vendors
		rename_table :customers, :spree_customers
  end
end
