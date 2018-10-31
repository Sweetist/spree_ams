class ChangePromotionAdvertiseDefault < ActiveRecord::Migration
  def change
    change_column_default :spree_promotions, :advertise, true
  end
end
