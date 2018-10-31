FactoryGirl.define do
  factory :check_payment_method, class: Spree::PaymentMethod::Check do
    name 'Check'
  end
  factory :cash_payment_method, class: Spree::PaymentMethod::Cash do
    name 'Cash'
    auto_capture true
  end

  factory :credit_card_payment_method, class: Spree::Gateway::Bogus do
    name 'Credit Card'
  end

  # authorize.net was moved to spree_gateway.
  # Leaving this factory in place with bogus in case anyone is using it.
  factory :simple_credit_card_payment_method, class: Spree::Gateway::BogusSimple do
    name 'Credit Card'
  end

  factory :skrill_quick_checkout, class: Spree::BillingIntegration::Skrill::QuickCheckout do
    name 'Skrill - Quick Checkout'
  end
end
