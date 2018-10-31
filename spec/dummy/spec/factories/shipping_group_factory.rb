FactoryGirl.define do
  factory :shipping_group, class: Spree::ShippingGroup do
    name 'Daily'
    vendor
  end
end
