Spree::Stock::ContentItem.class_eval do
  def quantity
    @inventory_unit.quantity
  end

  def price
    line_item.discount_price
  end
end
