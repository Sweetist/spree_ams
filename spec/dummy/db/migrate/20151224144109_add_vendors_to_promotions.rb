class AddVendorsToPromotions < ActiveRecord::Migration
  def change
    add_column :spree_promotions, :vendor_id, :integer
  end
end
