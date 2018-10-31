class AddPositionToIntegrationSteps < ActiveRecord::Migration
  def change
    add_column :spree_integration_steps, :position, :integer, default: 1, null: false
    add_index  :spree_integration_steps, :position
  end
end
