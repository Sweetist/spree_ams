class AddFullOrDisplayNameToAccount < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :full_or_display_name, :string
    add_index :spree_accounts, :full_or_display_name
    remove_column :spree_customer_imports, :display_name
    remove_index :spree_accounts, :display_name
  end
end
