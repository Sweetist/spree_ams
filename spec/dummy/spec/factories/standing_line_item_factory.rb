FactoryGirl.define do
  factory :standing_line_item, class: Spree::StandingLineItem do
    quantity 1
    standing_order { |so| Spree::StandingOrder.first || so.association(:standing_order) }
    variant { |v| Spree::Variant.first || v.association(:variant) }
  end
end
