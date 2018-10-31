FactoryGirl.define do
  factory :credit_memo, class: 'Spree::CreditMemo' do
    account { |a| Spree::Account.first || a.association(:account) }
    vendor { |v| Spree::Company.first || v.association(:vendor) }
    item_total 0
    additional_tax_total 0
    included_tax_total 10
    shipment_total 20
    amount_remaining 30
    total 30
  end
end
