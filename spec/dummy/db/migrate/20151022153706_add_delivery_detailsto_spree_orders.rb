class AddDeliveryDetailstoSpreeOrders < ActiveRecord::Migration
  def change
		add_column :spree_orders, :delivery_date, :datetime
    add_column :spree_orders, :is_delivery?, :boolean, default: true
  end
end
