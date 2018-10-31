class AddLotTrackingToSpreeVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :lot_tracking, :boolean, default: false
  end
end
