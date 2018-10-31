FactoryGirl.define do
  factory :price_list_account, class: Spree::PriceListAccount do
    price_list
    account
  end
end
