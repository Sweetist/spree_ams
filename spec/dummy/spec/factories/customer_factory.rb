FactoryGirl.define do
  factory :customer, class: Spree::Company do
    name { Faker::Company.name }
    email { Faker::Internet.email }
    time_zone 'Eastern Time (US & Canada)'
    ship_address { create(:address) }
    bill_address { create(:address) }
    order_cutoff_time '5:00 PM'
    delivery_minimum 10
  end
end
