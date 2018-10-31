FactoryGirl.define do
  factory :base_product, class: Spree::Product do
    sequence(:name) { |n| "Product ##{n} - #{Kernel.rand(9999)}" }
    description { generate(:random_description) }
    price 19.99
    cost_price 17.00
    product_type "inventory_item"
    sku { generate(:sku) }
    available_on { 1.year.ago }
    deleted_at nil
    lead_time {3}
    shipping_category { |r| Spree::ShippingCategory.first || r.association(:shipping_category) }

    vendor { |v| Spree::Company.first || v.association(:vendor) }

    # ensure stock item will be created for this products master
    before(:create) { create(:stock_location) if Spree::StockLocation.count == 0 }

    factory :custom_product do
      name 'Custom Product'
      price 17.99

      tax_category { |r| Spree::TaxCategory.first || r.association(:tax_category) }
    end

    factory :product do
      tax_category { |r| Spree::TaxCategory.first || r.association(:tax_category) }

      factory :product_all_in_stock do
        after :create do |product|
          product.master.stock_items.each { |si| si.adjust_count_on_hand(10) }
        end
      end

      factory :product_in_stock do
        after :create do |product|
          product.master.stock_items.first.adjust_count_on_hand(10)
        end
      end

      factory :product_with_option_types do
        after(:create) { |product| create(:product_option_type, product: product) }
      end

      factory :lot_tracked_product do
        after(:create) do |product|
          product.master.stock_items.each { |si| si.adjust_count_on_hand(10) }
          product.master.update(lot_tracking: true)
          lot = create(:lot_with_stock_items, variant: product.master)

        end
      end

      factory :product_with_lot_tracked_parts do
        after :create do |product|
          part1 = create(:lot_tracked_product)
          part2 = create(:lot_tracked_product)

          product.master.parts_variants.create(part_id: part1.master.id, count: 1)
          product.master.parts_variants.create(part_id: part2.master.id, count: 2)

          product.reload
        end
      end
    end
  end
end
