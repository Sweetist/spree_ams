class AddTimeZonesToCustomersAndVendors < ActiveRecord::Migration
  def change
    add_column :spree_customers, :time_zone, :string
    add_column :spree_vendors, :time_zone, :string
  end
end
