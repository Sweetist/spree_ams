FactoryGirl.define do
  factory :customer_type, class: Spree::CustomerType do
    name 'Restaurant'
    vendor
  end
end
