class AddColorsToVendor < ActiveRecord::Migration
  def change
    add_column :spree_vendors, :theme_colors, :json
    add_column :spree_vendors, :theme_name, :string
    add_column :spree_vendors, :theme_css, :text, limit: 1048576
  end
end
