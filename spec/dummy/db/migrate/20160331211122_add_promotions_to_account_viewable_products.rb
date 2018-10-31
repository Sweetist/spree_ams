class AddPromotionsToAccountViewableProducts < ActiveRecord::Migration
  def change
    add_column :spree_account_viewable_products, :promotion_ids, :text, array:true, default: []
  end
end
