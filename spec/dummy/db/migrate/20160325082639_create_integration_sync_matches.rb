class CreateIntegrationSyncMatches < ActiveRecord::Migration
  def change
    create_table :spree_integration_sync_matches do |t|
      t.integer    :integration_syncable_id
      t.string     :integration_syncable_type
      t.references :integration_item
      t.integer    :sync_id
      t.string     :sync_type
    end

    add_index :spree_integration_sync_matches, :integration_syncable_id
    add_index :spree_integration_sync_matches, :integration_syncable_type, name: "index_spreeintegrationsyncmatches_on_integrationsyncabletype"
    add_index :spree_integration_sync_matches, [:integration_syncable_id, :integration_syncable_type], name: "index_spreeintegrationsyncmatches_on_integrationsyncable"
    add_index :spree_integration_sync_matches, :integration_item_id
    add_index :spree_integration_sync_matches, [:integration_item_id, :integration_syncable_id, :integration_syncable_type], name: "index_spreeintegrationsyncmatches_on_intemandsyncable"
    add_index :spree_integration_sync_matches, :sync_id
    add_index :spree_integration_sync_matches, :sync_type
    add_index :spree_integration_sync_matches, [:sync_id, :sync_type]
  end
end
