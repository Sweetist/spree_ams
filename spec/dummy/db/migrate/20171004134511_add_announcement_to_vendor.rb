class AddAnnouncementToVendor < ActiveRecord::Migration
  def change
    add_column :spree_customer_viewable_attributes, :announcement, :text
  end
end
