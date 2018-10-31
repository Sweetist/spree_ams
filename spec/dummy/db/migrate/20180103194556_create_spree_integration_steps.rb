class CreateSpreeIntegrationSteps < ActiveRecord::Migration
  def change
    create_table :spree_integration_steps do |t|
      t.integer :integration_action_id
      t.integer :parent_id
      t.integer :status, default: 0, null: false
      t.string  :integrationable_type
      t.jsonb   :details, default: {}, null: false

      t.timestamps
    end

    add_index :spree_integration_steps, :integration_action_id
    add_index :spree_integration_steps, :parent_id
  end
end
