class RenameTimeoutOffOnSpreeIntegrationItem < ActiveRecord::Migration
  def change
    rename_column :spree_integration_items, :timeout_off, :should_timeout
  end
end
