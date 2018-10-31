class AddSyncAttrsToIntegrationActions < ActiveRecord::Migration
  def change
    add_column :spree_integration_actions, :sync_id, :string
    add_column :spree_integration_actions, :sync_type, :string
    add_column :spree_integration_actions, :sync_fully_qualified_name, :string
    add_index  :spree_integration_actions, :sync_id
    add_index  :spree_integration_actions, :sync_type
    add_index  :spree_integration_actions, :sync_fully_qualified_name
  end
end
