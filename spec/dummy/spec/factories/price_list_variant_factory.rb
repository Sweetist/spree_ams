FactoryGirl.define do
  factory :price_list_variant, class: Spree::PriceListVariant do
    price_list
    variant
  end
end
