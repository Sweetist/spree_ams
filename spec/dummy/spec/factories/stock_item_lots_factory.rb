FactoryGirl.define do
  factory :stock_item_lot, class: Spree::StockItemLots do
    lot
    stock_item
    count 50
  end
end
