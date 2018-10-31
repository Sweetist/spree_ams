class AddInvoiceSettingsToVendor < ActiveRecord::Migration
  def change
    add_column :spree_vendors, :invoice_settings, :json
  end
end
