class AddPreferredVendorToVariant < ActiveRecord::Migration
  def change
    add_column :spree_variants, :preferred_vendor_account_id, :integer
    rename_column :spree_variant_vendors, :price, :cost_price
  end
end
