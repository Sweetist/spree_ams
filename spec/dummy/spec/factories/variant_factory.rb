FactoryGirl.define do
  sequence(:random_float) { BigDecimal.new("#{rand(200)}.#{rand(99)}") }

  factory :base_variant, class: Spree::Variant do
    price 19.99
    cost_price 17.00
    pack_size 'Each'
    sku    { generate(:sku) }
    weight { generate(:random_float) }
    weight_units 'lb'
    height { generate(:random_float) }
    width  { generate(:random_float) }
    depth  { generate(:random_float) }
    dimension_units 'in'
    is_master 0
    track_inventory true
    variant_type 'inventory_item'
    minimum_order_quantity 0

    product { |p| p.association(:base_product) }
    option_values { [create(:option_value)] }

    # ensure stock item will be created for this variant
    before(:create) { create(:stock_location) if Spree::StockLocation.count == 0 }

    factory :variant do
      # on_hand 5
      product { |p| p.association(:product) }
    end

    factory :master_variant do
      is_master 1
    end

    factory :on_demand_variant do
      track_inventory false

      factory :on_demand_master_variant do
        is_master 1
      end
    end
  end

  factory :variant_in_stock, parent: :variant do
    transient do
      quantity_in_stock 10
    end

    after(:create) do |variant, evaluator|
      variant.stock_items.first.adjust_count_on_hand(
        evaluator.quantity_in_stock
      )
    end
  end

  factory :variant_in_full_stock, parent: :variant do
    transient do
      quantity_in_stock 10
    end

    after(:create) do |variant, evaluator|
      variant.stock_items.each do |item|
        item.adjust_count_on_hand(
          evaluator.quantity_in_stock
        )
      end
    end
  end
end
