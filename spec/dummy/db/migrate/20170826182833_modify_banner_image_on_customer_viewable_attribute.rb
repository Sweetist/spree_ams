class ModifyBannerImageOnCustomerViewableAttribute < ActiveRecord::Migration
  def change
    remove_column :spree_customer_viewable_attributes, :banner_image_file_name
    remove_column :spree_customer_viewable_attributes, :banner_image_content_type
    remove_column :spree_customer_viewable_attributes, :banner_image_file_size
    remove_column :spree_customer_viewable_attributes, :banner_image_updated_at
    remove_column :spree_customer_viewable_attributes, :banner_inp_sel_method

    add_column :spree_customer_viewable_attributes, :banner_image_id, :integer
  end
end
