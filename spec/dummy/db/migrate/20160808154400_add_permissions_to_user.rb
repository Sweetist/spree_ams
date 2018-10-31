class AddPermissionsToUser < ActiveRecord::Migration
  def change
  	add_column :spree_users, :permissions, :jsonb
		add_column :spree_users, :permission_groups_id, :integer

  	add_index :spree_users, :permission_groups_id
  end
end
