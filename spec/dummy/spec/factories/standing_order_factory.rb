FactoryGirl.define do
  factory :standing_order, class: Spree::StandingOrder do
    name { Faker::Company.name }
    user
    start_at { Date.current + 1.day }
    vendor { |v| Spree::Company.first || v.association(:vendor) }
    customer { |c| Spree::Company.first || c.association(:customer) }
    account { create(:account, customer: customer, vendor: vendor) }
    shipping_method { |c| Spree::ShippingMethod.first || c.association(:shipping_method) }

    factory :standing_order_with_totals do
      transient do
        line_items_price 100
      end
      after(:create) do |standing_order, evaluator|
        variant = create(:variant, price: evaluator.line_items_price)
        create(:account_viewable_variant, variant: variant,
                                          price: variant.price,
                                          account: standing_order.account)
        create(:standing_line_item, standing_order: standing_order,
                                    variant: variant)
        standing_order.standing_line_items.reload
      end
    end

    factory :standing_order_with_line_items do

      transient do
        line_items_count 1
        return_items_count { line_items_count }
      end

      after(:create) do |standing_order, evaluator|
        variant = standing_order.vendor.variants_for_sale.last || create(:variant)
        create_list(:standing_line_item, evaluator.line_items_count, standing_order: standing_order, variant: variant)
        standing_order.standing_line_items.reload
      end
    end
  end
end
