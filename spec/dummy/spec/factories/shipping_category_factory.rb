FactoryGirl.define do
  factory :shipping_category, class: Spree::ShippingCategory do
    sequence(:name) { |n| "ShippingCategory ##{n}" }
    vendor { |v| Spree::Company.first || v.association(:vendor) }
  end
end
