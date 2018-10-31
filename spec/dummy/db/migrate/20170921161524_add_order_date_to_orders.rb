class AddOrderDateToOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :order_date, :datetime
    add_index  :spree_orders, :order_date
  end
end