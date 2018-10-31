class AddShippingMethodToStandingOrder < ActiveRecord::Migration
  def change
    add_column :spree_standing_orders, :shipping_method_id, :integer
  end
end
