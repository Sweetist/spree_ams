class ChangeIntegrationSyncIdColumnType < ActiveRecord::Migration
  def change
    change_column :spree_integration_sync_matches, :sync_id, :string
  end
end
