FactoryGirl.define do
  factory :price_list, class: Spree::PriceList do
    sequence(:name) { |n| "Price List ##{n}" }
    vendor
    active true
  end
end
