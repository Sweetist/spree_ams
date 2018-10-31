class AddVendorSettings < ActiveRecord::Migration
  def change
    add_column :spree_vendors, :settings, :json, default: {}
  end
end
