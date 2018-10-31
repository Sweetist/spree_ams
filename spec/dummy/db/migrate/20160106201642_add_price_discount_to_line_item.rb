class AddPriceDiscountToLineItem < ActiveRecord::Migration
  def change
    add_column :spree_line_items, :price_discount, :decimal, default: 0.0
  end
end
