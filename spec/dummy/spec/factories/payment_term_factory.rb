FactoryGirl.define do
  factory :payment_term, class: Spree::PaymentTerm do
    name 'Net 30'
    num_days 30
    pay_before_submit false

    factory :payment_term_cc do
      name 'Credit Card'
      num_days 0
      pay_before_submit true
    end
  end
end
