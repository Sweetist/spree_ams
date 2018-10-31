class AddTimeoutOffAndLastResponseTimeToSpreeIntegrationActions < ActiveRecord::Migration
  def change
    add_column :spree_integration_items, :timeout_off, :boolean, default: false
    add_column :spree_integration_actions, :last_response_time, :datetime
  end
end
