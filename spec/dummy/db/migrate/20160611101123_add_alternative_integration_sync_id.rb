class AddAlternativeIntegrationSyncId < ActiveRecord::Migration
  def change
    add_column :spree_integration_sync_matches, :sync_alt_id, :string
  end
end
