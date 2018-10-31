class ChangePriceListsActiveDefault < ActiveRecord::Migration
  def change
    change_column_default :spree_price_lists, :active, true
  end
end
