FactoryGirl.define do
  factory :order_rule, class: Spree::OrderRule do
    vendor { |v| Spree::Company.first || v.association(:vendor) }
    rule_type 1
    value 2
    active true
    taxon_ids nil
  end
end
