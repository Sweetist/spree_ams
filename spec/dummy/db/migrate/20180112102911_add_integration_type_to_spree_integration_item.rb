class AddIntegrationTypeToSpreeIntegrationItem < ActiveRecord::Migration
  def change
    add_column :spree_integration_items, :integration_type, :integer
  end
end
