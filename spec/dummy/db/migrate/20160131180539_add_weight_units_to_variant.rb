class AddWeightUnitsToVariant < ActiveRecord::Migration
  def change
    add_column :spree_variants, :weight_units, :string
  end
end
