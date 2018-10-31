FactoryGirl.define do
  factory :vendor, class: Spree::Company do
    name { Faker::Company.name }
    order_cutoff_time '5:00 PM'
    delivery_minimum 10
    # slug { Faker::Internet.slug }
    email { Faker::Internet.email }
    time_zone 'Eastern Time (US & Canada)'
    bill_address { create(:address) }
    subscription 'platinum'
    track_inventory true
    custom_domain ''

    factory :vendor_with_vendor_user do
      after(:create) do |vendor|
        user = create(:vendor_user)
        vendor.users << user
      end
    end
    factory :vendor_with_stock_location do
      after(:create) do |vendor|
        stock_location = create(:stock_location)
        vendor.stock_locations << stock_location
      end
    end
  end
end
