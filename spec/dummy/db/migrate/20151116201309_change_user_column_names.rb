class ChangeUserColumnNames < ActiveRecord::Migration
  def change
    rename_column :spree_users, :user_type, :position
    rename_column :spree_users, :is_master, :is_admin
  end
end
