class AddShippingMethodLimiterToAccount < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :default_shipping_method_only, :boolean, null: false, default: false
  end
end
