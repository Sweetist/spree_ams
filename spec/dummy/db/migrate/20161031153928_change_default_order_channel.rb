class ChangeDefaultOrderChannel < ActiveRecord::Migration
  def change
    change_column_default :spree_orders, :channel, 'sweet'
  end
end
