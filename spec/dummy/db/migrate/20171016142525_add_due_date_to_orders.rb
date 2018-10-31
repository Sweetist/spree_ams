class AddDueDateToOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :due_date, :datetime
    add_index  :spree_orders, :due_date
  end
end
