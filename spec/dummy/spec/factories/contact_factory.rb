FactoryGirl.define do
  factory :contact, class: Spree::Contact do
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }
    company_name { Faker::Company.name }
    email { Faker::Internet.email }
    phone { Faker::PhoneNumber.phone_number }
    addresses { Faker::Address.street_address }
    company { |c| Spree::Company.first || c.association(:company) }
    account_ids {[""]}
  end
end
