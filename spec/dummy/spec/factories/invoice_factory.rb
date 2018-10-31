FactoryGirl.define do
  factory :invoice, class: Spree::Invoice do
    sequence(:number) { |n| "0000#{n}" }
    bill_address
    ship_address
    start_date { Date.current }
    end_date { Date.current }
    due_date { Date.current }
    invoice_date { Date.current }
    vendor { |v| Spree::Company.first || v.association(:vendor) }
    account { |a| Spree::Account.first || a.association(:account) }
  end
end
