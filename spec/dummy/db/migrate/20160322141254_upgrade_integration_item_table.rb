class UpgradeIntegrationItemTable < ActiveRecord::Migration
  def change
    drop_table :integration_items if ActiveRecord::Base.connection.table_exists? 'integration_items'
    # drop_table :spree_integration_items if ActiveRecord::Base.connection.table_exists? 'spree_integration_items'

    create_table :spree_integration_items do |t|
      t.references :vendor
      t.string :integration_key
      t.json :settings
      t.integer :status
      t.timestamps null: false
    end
    
    add_index :spree_integration_items, :vendor_id
    add_index :spree_integration_items, :integration_key
    add_index :spree_integration_items, [:vendor_id, :integration_key]

    create_table :spree_integration_actions do |t|
      t.integer :integrationable_id
      t.string  :integrationable_type
      t.references :integration_item
      t.integer :status
      t.text :execution_log
      t.integer :execution_count
      t.datetime :enqueued_at
      t.datetime :processed_at
    end

    add_index :spree_integration_actions, :integrationable_id
    add_index :spree_integration_actions, :integrationable_type
    add_index :spree_integration_actions, [:integrationable_id, :integrationable_type], name: 'spree_integration_actions_on_integrationable'
    add_index :spree_integration_actions, :integration_item_id
    add_index :spree_integration_actions, :status
    add_index :spree_integration_actions, [:integrationable_id, :integrationable_type, :status], name: 'spree_integration_actions_on_integrationable_status'
    add_index :spree_integration_actions, :enqueued_at
    add_index :spree_integration_actions, :processed_at
  end
end
