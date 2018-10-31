class AddBannerColorAndAboutUsToSpreeCustomerViewableAttributes < ActiveRecord::Migration
  def change
    add_column :spree_customer_viewable_attributes, :banner_color, :string
    add_column :spree_customer_viewable_attributes, :about_us, :text
  end
end
