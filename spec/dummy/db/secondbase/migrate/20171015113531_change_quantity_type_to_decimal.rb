class ChangeQuantityTypeToDecimal < ActiveRecord::Migration
  # Removing this because it does not work with redshift
  # def up
  #   change_column :inventory_change_histories, :quantity, :decimal, precision: 15, scale: 5
  #   change_column :inventory_change_histories, :quantity_on_hand, :decimal, precision: 15, scale: 5
  # end
end
