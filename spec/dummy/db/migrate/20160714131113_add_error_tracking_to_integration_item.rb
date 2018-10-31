class AddErrorTrackingToIntegrationItem < ActiveRecord::Migration
  def change
    add_column :spree_integration_items, :last_action, :text
    add_column :spree_integration_items, :last_error, :text
  end
end
