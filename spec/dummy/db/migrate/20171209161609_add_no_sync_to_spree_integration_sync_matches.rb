class AddNoSyncToSpreeIntegrationSyncMatches < ActiveRecord::Migration
  def change
    add_column :spree_integration_sync_matches, :no_sync, :boolean, default: false
  end
end
