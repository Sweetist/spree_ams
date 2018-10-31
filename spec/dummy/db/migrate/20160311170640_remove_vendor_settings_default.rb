class RemoveVendorSettingsDefault < ActiveRecord::Migration
  def change
    remove_column :spree_vendors, :settings
    add_column :spree_vendors, :settings, :json
  end
end
