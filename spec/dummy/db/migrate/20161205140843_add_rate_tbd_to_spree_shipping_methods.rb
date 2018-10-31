class AddRateTbdToSpreeShippingMethods < ActiveRecord::Migration
  def change
    add_column :spree_shipping_methods, :rate_tbd, :boolean, default: false
  end
end
