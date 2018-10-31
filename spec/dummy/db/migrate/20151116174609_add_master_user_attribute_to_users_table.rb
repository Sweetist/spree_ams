class AddMasterUserAttributeToUsersTable < ActiveRecord::Migration
  def change
    add_column :spree_users, :is_master, :boolean, default: false
  end
end
