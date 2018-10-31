class AddActivityAttributesToAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :name, :string
    add_column :spree_accounts, :active_date, :datetime
    add_column :spree_accounts, :inactive_date, :datetime
    add_column :spree_accounts, :inactive_reason, :string

    add_index :spree_accounts, :name
    add_index :spree_accounts, :inactive_date
  end
end
