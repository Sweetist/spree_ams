FactoryGirl.define do
  factory :lot, class: Spree::Lot do
    sequence(:number) { |n| "number#{n}" }
    variant { create(:variant) }
    vendor { |v| Spree::Company.first || v.association(:vendor) }
    sell_by { Date.today + 30 }

    transient do
      quantity_in_stock 10
    end

    factory :lot_with_stock_items do
    expires_at { Date.today + 30 }
    available_at { Date.today - 3 }
      after(:create) do |lot, evaluator|
        lot.update_column :qty_on_hand, evaluator.quantity_in_stock
        create(:stock_item_lot, lot: lot,
                                stock_item: lot.variant.stock_items.first,
                                count: evaluator.quantity_in_stock)
      end
    end

    factory :lot_with_fully_stocked_items do
      expires_at { Date.today + 30 }
      available_at { Date.today - 3 }
      variant { create(:variant_in_full_stock) }

      after(:create) do |lot, evaluator|
        total = 0
        lot.variant.stock_items.each do |item|
          count_on_hand = item.count_on_hand
          count_on_hand = evaluator.quantity_in_stock if count_on_hand.zero?
          create(:stock_item_lot, lot: lot,
                                  stock_item: item,
                                  count: count_on_hand)
          total += count_on_hand
        end
        lot.update_column :qty_on_hand, total
      end
    end
  end
end
