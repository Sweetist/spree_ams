class AddPriceListIdToAccountViewableVariants < ActiveRecord::Migration
  def change
    add_column :spree_account_viewable_variants, :price_list_id, :integer
    add_index  :spree_account_viewable_variants, :price_list_id
  end
end
