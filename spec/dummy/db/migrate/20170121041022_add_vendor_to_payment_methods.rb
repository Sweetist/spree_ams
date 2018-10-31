class AddVendorToPaymentMethods < ActiveRecord::Migration
  def change
    add_column :spree_payment_methods, :vendor_id, :integer
    add_index :spree_payment_methods, :vendor_id
  end
end
