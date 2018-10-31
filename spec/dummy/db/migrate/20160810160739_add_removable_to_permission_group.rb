class AddRemovableToPermissionGroup < ActiveRecord::Migration
  def change
  	add_column :spree_permission_groups, :removable, :boolean, default: true
  end
end
