class AddSyncBooleansToIntegrationItems < ActiveRecord::Migration
  def change
    add_column :spree_integration_items, :order_sync, :boolean
    add_column :spree_integration_items, :account_sync, :boolean
    add_column :spree_integration_items, :variant_sync, :boolean
    add_index :spree_integration_items, :order_sync
    add_index :spree_integration_items, :account_sync
    add_index :spree_integration_items, :variant_sync
  end
end
