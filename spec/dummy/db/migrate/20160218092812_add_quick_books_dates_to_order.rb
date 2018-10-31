class AddQuickBooksDatesToOrder < ActiveRecord::Migration
  def change
    add_column :spree_orders, :quickbooks_created_at, :datetime
    add_column :spree_orders, :quickbooks_updated_at, :datetime
  end
end
