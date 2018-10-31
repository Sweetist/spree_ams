FactoryGirl.define do
  factory :stock_transfer, class: Spree::StockTransfer do
    association :source_location, factory: :stock_location_with_items, name: 'Source Warehouse'
    association :destination_location, factory: :stock_location, name: 'Destination Warehouse'
    company
    reference 'transfer reference'
    transfer_type 'test'
  end
end
