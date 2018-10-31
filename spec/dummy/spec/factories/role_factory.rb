FactoryGirl.define do
  factory :role, class: Spree::Role do
    sequence(:name) { |n| "Role ##{n}" }

    factory :admin_role do
      name 'admin'
    end

    factory :customer_role do
      name 'customer'
    end

    factory :vendor_role do
      name 'customer'
    end
  end
end
