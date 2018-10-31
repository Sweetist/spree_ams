class AddTimestampsToIntegrationActions < ActiveRecord::Migration
  def change
    add_timestamps :spree_integration_actions
    add_timestamps :spree_integration_sync_matches
  end
end
