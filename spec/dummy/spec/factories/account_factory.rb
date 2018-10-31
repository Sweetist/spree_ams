FactoryGirl.define do
  factory :account, class: Spree::Account do
    vendor { |v| Spree::Company.first || v.association(:vendor) }
    customer { |c| Spree::Company.first || c.association(:customer) }
    number {rand(1000000...10000000)}
    payment_terms { |pt| Spree::PaymentTerm.first || pt.association(:payment_term)}
    name {Faker::Company.name}
    display_name {Faker::Name.name}
    taxable true

    factory :account_with_addresses do
      after(:create) do |account|
        account.default_ship_address = account_address_ship = create(:address, account_id: account.id, addr_type: 'shipping')
        account.bill_address = account_address_bill = create(:address, account_id: account.id, addr_type: 'billing')
      end
    end
  end
end
