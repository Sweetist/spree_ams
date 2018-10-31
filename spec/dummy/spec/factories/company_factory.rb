FactoryGirl.define do
  factory :company, class: Spree::Company do
    name { Faker::Company.name }
    order_cutoff_time '5:00 PM'
    delivery_minimum 10
    slug { Faker::Internet.slug }
    email { Faker::Internet.email }
    time_zone 'Eastern Time (US & Canada)'
    bill_address { create(:address) }
    subscription 'platinum'
    track_inventory true
    custom_domain ''
  end
end
