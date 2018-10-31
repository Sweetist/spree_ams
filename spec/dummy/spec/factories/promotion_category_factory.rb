FactoryGirl.define do
  factory :promotion_category, class: Spree::PromotionCategory do
    name 'Promotion Category'
    vendor { |v| Spree::Company.first || v.association(:vendor) }
  end
end
