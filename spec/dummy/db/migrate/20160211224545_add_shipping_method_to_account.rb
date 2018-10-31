class AddShippingMethodToAccount < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :default_shipping_method_id, :integer
    add_index :spree_accounts, :default_shipping_method_id
  end
end
