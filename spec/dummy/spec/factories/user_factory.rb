FactoryGirl.define do
  sequence :user_authentication_token do |n|
    "xxxx#{Time.now.to_i}#{rand(1000)}#{n}xxxxxxxxxxxxx"
  end

  factory :user, class: Spree.user_class do
    email { generate(:random_email) }
    login { email }
    password 'secret'
    firstname 'John'
    lastname 'Doe'
    password_confirmation { password }
    authentication_token { generate(:user_authentication_token) } if Spree.user_class.attribute_method? :authentication_token

    company { |c| Spree::Company.first || c.association(:company) }
    factory :admin_user do
      spree_roles { [Spree::Role.find_by(name: 'admin') || create(:role, name: 'admin')] }
    end

    factory :vendor_user do
      spree_roles { [Spree::Role.find_by(name: 'vendor') || create(:role, name: 'vendor')] }
    end

    factory :customer_user do
      spree_roles { [Spree::Role.find_by(name: 'customer') || create(:role, name: 'customer')] }
    end

    factory :user_with_addresses, aliases: [:user_with_addreses] do
      ship_address
      bill_address
    end
  end
end
