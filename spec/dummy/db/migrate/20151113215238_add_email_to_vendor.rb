class AddEmailToVendor < ActiveRecord::Migration
  def change
    add_column :spree_vendors, :email, :string
  end
end
