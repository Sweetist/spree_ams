class AddComponentCostSumToVariant < ActiveRecord::Migration
  def change
    add_column :spree_variants, :sum_cost_price, :decimal, precision: 10, scale: 2, default: 0, null: false
  end
end
