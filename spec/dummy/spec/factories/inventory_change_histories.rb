FactoryGirl.define do
  factory :inventory_change_history, class: Spree::InventoryChangeHistory do
    stock_movement_id { (1..4).to_a.sample }
    stock_item_id { (1..4).to_a.sample }
    stock_location_id { (1..4).to_a.sample }
    user_id { (1..4).to_a.sample }
    company_id 1
    variant_id { (1..4).to_a.sample }
    customer_id { (1..4).to_a.sample }
    action { InventoryHistory::ACTION_TYPES.values.sample }
    reason 'test reason'
    customer_type_id { (1..2).to_a.sample }
    pack_size { (1..4).to_a.sample }
    quantity { (1..40).to_a.sample }
    quantity_on_hand { (1..40).to_a.sample }
    originator_id { (1..4).to_a.sample }
    originator_type 'Test::Class'
    originator_created_at Time.zone.now
    originator_updated_at Time.zone.now
    originator_number { (1..400).to_a.sample }
    item_variant_name { "#{variant_id}_variant_name" }
    item_variant_sku  { "#{variant_id}_variant_sku" }
    stock_location_name { "#{stock_location_id}_stock_location_name" }
    customer_type_name { "#{customer_type_id}_customer_name" }

    after(:create) do |ich|
      if ich.action == InventoryHistory::ACTION_TYPES[:transfer]
        ich.source_location_id = 4
        ich.source_location_name = 'source_location_name'
      end

      ich.reason = nil if ich.action == InventoryHistory::ACTION_TYPES[:invoice]

      ich.save!
    end
  end
end
