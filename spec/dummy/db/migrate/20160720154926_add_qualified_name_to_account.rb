class AddQualifiedNameToAccount < ActiveRecord::Migration
  def change
	add_column :spree_accounts, :fully_qualified_name, :string
	add_index :spree_accounts, :fully_qualified_name
  end
end
