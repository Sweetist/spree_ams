class AddDisplayNameToAccount < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :display_name, :string
    add_index :spree_accounts, :display_name
  end
end
