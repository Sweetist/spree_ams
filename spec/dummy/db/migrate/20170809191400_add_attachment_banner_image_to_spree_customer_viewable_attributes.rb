class AddAttachmentBannerImageToSpreeCustomerViewableAttributes < ActiveRecord::Migration
  def self.up
    change_table :spree_customer_viewable_attributes do |t|
      t.attachment :banner_image
    end
  end

  def self.down
    remove_attachment :spree_customer_viewable_attributes, :banner_image
  end
end
