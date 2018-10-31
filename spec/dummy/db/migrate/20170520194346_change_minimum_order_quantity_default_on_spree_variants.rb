class ChangeMinimumOrderQuantityDefaultOnSpreeVariants < ActiveRecord::Migration
  def up
    change_column :spree_variants, :minimum_order_quantity, :integer, default: 0, null: false
  end

  def down
    change_column :spree_variants, :minimum_order_quantity, :integer
  end
end
