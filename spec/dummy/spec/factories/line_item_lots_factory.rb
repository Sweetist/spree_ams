FactoryGirl.define do
  factory :line_item_lot, class: Spree::LineItemLots do
   lot {Spree::Lot.first}
   line_item {Spree::LineItem.first}
   count 1
  end
end
