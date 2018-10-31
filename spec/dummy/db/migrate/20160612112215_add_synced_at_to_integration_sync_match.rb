class AddSyncedAtToIntegrationSyncMatch < ActiveRecord::Migration
  def change
    add_column :spree_integration_sync_matches, :synced_at, :datetime
  end
end
