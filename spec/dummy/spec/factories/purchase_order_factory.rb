FactoryGirl.define do
  factory :purchase_order, class: Spree::Order do
    user
    bill_address
    ship_address
    shipping_method
    completed_at nil
    email { user.try(:email) }
    delivery_date { Date.current }
    store
    vendor { |v| Spree::Company.first || v.association(:vendor) }
    customer { |c| Spree::Company.first || c.association(:customer) }
    account { |a| Spree::Account.first || a.association(:account) }
    order_type "purchase"

    transient do
      line_items_price BigDecimal.new(10)
    end

    factory :purchase_order_with_totals do
      after(:create) do |order, evaluator|
        create(:line_item, order: order, price: evaluator.line_items_price)
        order.line_items.reload # to ensure order.line_items is accessible after
      end
    end

    factory :purchase_order_with_line_item_quantity do
      transient do
        line_items_quantity 1
      end

      after(:create) do |order, evaluator|
        create(:line_item, order: order, price: evaluator.line_items_price, quantity: evaluator.line_items_quantity)
        order.line_items.reload # to ensure order.line_items is accessible after
      end
    end

    factory :purchase_order_with_line_items do
      bill_address
      ship_address

      transient do
        line_items_count 1
        shipment_cost 100
        shipping_method_filter Spree::ShippingMethod::DISPLAY_ON_FRONT_END
      end

      after(:create) do |order, evaluator|
        create_list(:line_item, evaluator.line_items_count, order: order, price: evaluator.line_items_price)
        order.line_items.reload

        create(:shipment, order: order, cost: evaluator.shipment_cost)
        order.shipments.reload

        order.update!
      end

      factory :purchase_completed_order_with_totals do
        state 'complete'

        after(:create) do |order, evaluator|
          order.refresh_shipment_rates(evaluator.shipping_method_filter)
          order.update_column(:completed_at, Time.current)
        end

        factory :purchase_completed_order_with_pending_payment do
          after(:create) do |order|
            # TODO: Fix payment creation on Order Factory
            # create(:payment, amount: order.total, order: order)
          end
        end

        factory :purchase_order_ready_to_ship do
          payment_state 'paid'
          shipment_state 'ready'

          after(:create) do |order|
            # TODO: Fix payment creation on Order Factory
            # create(:payment, amount: order.total, order: order, state: 'completed')
            order.shipments.each do |shipment|
              shipment.inventory_units.update_all state: 'on_hand'
              shipment.update_column('state', 'ready')
            end
            order.reload
          end

          factory :shipped_purchase_order do
            after(:create) do |order|
              order.shipments.each do |shipment|
                shipment.inventory_units.update_all state: 'shipped'
                shipment.update_column('state', 'shipped')
              end
              order.reload
            end
          end
        end
      end
    end
  end
end
