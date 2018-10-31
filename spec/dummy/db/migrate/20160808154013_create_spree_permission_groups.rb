class CreateSpreePermissionGroups < ActiveRecord::Migration
  def change
    create_table :spree_permission_groups do |t|
      t.string  :name, null: false
      t.integer :company_id
      t.jsonb    :permissions
      t.boolean :is_default, default: false
    end

 		add_index :spree_permission_groups, :company_id
		add_index :spree_permission_groups, :is_default
  end
end
