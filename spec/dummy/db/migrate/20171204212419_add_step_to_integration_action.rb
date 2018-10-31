class AddStepToIntegrationAction < ActiveRecord::Migration
  def change
    add_column :spree_integration_actions, :prev_step, :jsonb
    add_column :spree_integration_actions, :step, :jsonb
  end
end
