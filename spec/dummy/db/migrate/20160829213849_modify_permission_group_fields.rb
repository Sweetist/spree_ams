class ModifyPermissionGroupFields < ActiveRecord::Migration
  def change
    remove_column :spree_permission_groups, :removable, :boolean
    rename_column :spree_users, :permission_groups_id, :permission_group_id
  end
end
