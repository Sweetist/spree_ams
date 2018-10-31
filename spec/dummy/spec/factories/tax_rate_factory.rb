FactoryGirl.define do
  factory :tax_rate, class: Spree::TaxRate do
    zone
    name { "TaxRate - #{rand(999999)}" }
    amount 0.1
    tax_category
    association(:calculator, factory: :default_tax_calculator)
  end
end
