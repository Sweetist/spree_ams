class AddSyncInformationToIntegrationStep < ActiveRecord::Migration
  def change
    add_column :spree_integration_steps, :is_current, :boolean, default: false, null: false
    add_column :spree_integration_steps, :sync_id, :string
    add_column :spree_integration_steps, :sync_type, :string
    add_column :spree_integration_steps, :integration_syncable_id, :integer
    add_column :spree_integration_steps, :master, :string, default: 'sweet'
    add_index  :spree_integration_steps, :is_current
    add_index  :spree_integration_steps, :sync_id
    add_index  :spree_integration_steps, :sync_type
    add_index  :spree_integration_steps, :integration_syncable_id
  end
end
