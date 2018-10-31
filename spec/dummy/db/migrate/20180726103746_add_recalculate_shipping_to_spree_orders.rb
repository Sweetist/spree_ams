class AddRecalculateShippingToSpreeOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :recalculate_shipping, :boolean, default: false
  end
end
