class AddIntegrationTimeStampsToSyncMatches < ActiveRecord::Migration
  def change
    add_column :spree_integration_sync_matches, :sync_object_created_at, :string
    add_column :spree_integration_sync_matches, :sync_object_updated_at, :string
  end
end
