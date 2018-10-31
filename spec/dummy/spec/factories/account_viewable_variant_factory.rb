FactoryGirl.define do
  factory :account_viewable_variant, class: Spree::AccountViewableVariant do
    account
    variant
    price 9.99
    visible true
  end
end
