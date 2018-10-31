class AddOrderTypetoOrder < ActiveRecord::Migration
  def change
		add_column :spree_orders, :order_type, :string, default: "sales"
  end
end
