class AddDiscountMethodsToPriceLists < ActiveRecord::Migration
  def change
    add_column :spree_price_lists, :adjustment_method, :string, default: 'custom'
    add_column :spree_price_lists, :adjustment_operator, :integer, default: -1
    add_column :spree_price_lists, :adjustment_value, :decimal
  end
end
