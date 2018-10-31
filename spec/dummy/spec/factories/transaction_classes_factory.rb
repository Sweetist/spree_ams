FactoryGirl.define do
  sequence :name do |n|
    "Ut enim ad minim veniam #{n}"
  end

  factory :transaction_class, class: Spree::TransactionClass do
    name
    vendor { |v| Spree::Company.first || v.association(:vendor) }
  end

end
