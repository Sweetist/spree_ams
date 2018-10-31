class AddApprovedToOrder < ActiveRecord::Migration
  def change
    add_column :spree_orders, :approved, :boolean, default: false
  end
end
