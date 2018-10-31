class AddParentToAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :parent_id, :integer
    add_index :spree_accounts, :parent_id
  end
end
