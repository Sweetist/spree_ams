class AddVendorToPromotionCategories < ActiveRecord::Migration
  def change
    add_column :spree_promotion_categories, :vendor_id, :integer
    add_index :spree_promotion_categories, :vendor_id
  end
end
