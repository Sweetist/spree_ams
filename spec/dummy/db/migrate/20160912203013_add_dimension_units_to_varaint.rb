class AddDimensionUnitsToVaraint < ActiveRecord::Migration
  def change
    add_column :spree_variants, :dimension_units, :string
  end
end
