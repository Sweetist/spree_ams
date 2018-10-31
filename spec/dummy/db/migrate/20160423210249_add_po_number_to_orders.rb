class AddPoNumberToOrders < ActiveRecord::Migration
  def change
    add_column :spree_orders, :po_number, :string
    add_index :spree_orders, :po_number
  end
end
