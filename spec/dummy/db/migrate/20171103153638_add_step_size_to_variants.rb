class AddStepSizeToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :incremental_order_quantity, :decimal, precision: 15, scale: 5, default: 1, null: false
  end
end
