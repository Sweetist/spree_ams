class AddSidekiqJidToIntegrationActions < ActiveRecord::Migration
  def change
    add_column :spree_integration_actions, :sidekiq_jid, :string
  end
end
