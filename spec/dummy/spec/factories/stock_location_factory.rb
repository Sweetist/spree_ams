FactoryGirl.define do
  factory :stock_location, class: Spree::StockLocation do
    sequence(:name) { |n| "Warehouse ##{n} - #{Kernel.rand(9999)}" }
    address1 '1600 Pennsylvania Ave NW'
    city 'New York'
    zipcode '10018'
    phone '(202) 456-1111'
    active true
    backorderable_default true
    vendor { |v| Spree::Company.first || v.association(:vendor) }

    country  { |stock_location| Spree::Country.find_by_name('United States') || stock_location.association(:country) }
    state do |stock_location|
      stock_location.country.try(:states).try(:find_by_name, 'New York') || stock_location.association(:state, country: stock_location.country)
    end
    state_id {|stock_location| stock_location.state.try(:id) }

    factory :stock_location_with_items do
      after(:create) do |stock_location, evaluator|
        # variant will add itself to all stock_locations in an after_create
        # creating a product will automatically create a master variant
        product_1 = create(:product)
        product_2 = create(:product)

        stock_location.stock_items.where(variant_id: product_1.master.id).first.adjust_count_on_hand(10)
        stock_location.stock_items.where(variant_id: product_2.master.id).first.adjust_count_on_hand(20)
      end
    end
  end
end
