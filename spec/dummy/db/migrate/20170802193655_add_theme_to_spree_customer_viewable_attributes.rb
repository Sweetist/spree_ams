class AddThemeToSpreeCustomerViewableAttributes < ActiveRecord::Migration
  def change
    add_column :spree_customer_viewable_attributes, :theme_colors, :json
    add_column :spree_customer_viewable_attributes, :theme_name, :string
    add_column :spree_customer_viewable_attributes, :theme_css, :text, limit: 1048576
  end
end
