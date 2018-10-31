FactoryGirl.define do
  factory :tax_category, class: Spree::TaxCategory do
    name { "TaxCategory - #{rand(999999)}" }
    tax_code { "TAX" }
    description { generate(:random_string) }
    vendor { |v| Spree::Company.first || v.association(:vendor) }
  end
end
