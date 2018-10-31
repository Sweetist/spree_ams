class AddAccessLevelToVendor < ActiveRecord::Migration
  def change
    add_column :spree_vendors, :access_level, :integer, null: false, default: 0
  end
end
