class ChangeIntegrationTypeOnSpreeIntegrationItem < ActiveRecord::Migration
  def change
    change_column :spree_integration_items, :integration_type, :string
  end
end
