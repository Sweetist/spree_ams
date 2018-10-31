class AddCostingToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :costing_method, :string, default: 'fixed', null: false
    add_column :spree_variants, :avg_cost_price, :decimal, precision: 10, scale: 2, default: 0, null: false
    add_column :spree_variants, :last_cost_price, :decimal, precision: 10, scale: 2, default: 0, null: false
    change_column_default :spree_variants, :cost_price, 0
    change_column_null :spree_variants, :cost_price, false, 0

    add_index :spree_variants, :costing_method
  end
end
