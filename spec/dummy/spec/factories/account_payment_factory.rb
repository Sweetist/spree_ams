FactoryGirl.define do
  factory :account_payment, class: 'Spree::AccountPayment' do
    amount '9.99'
    currency 'USD'
    vendor { |v| Spree::Company.first || v.association(:vendor) }
    customer { |c| Spree::Company.first || c.association(:customer) }
    account { |a| Spree::Account.first || a.association(:account) }

    association(:payment_method, factory: :check_payment_method)

    after(:create) do |account_payment|
      # set right vendor for payment method
      account_payment.payment_method
                     .update_columns(vendor_id: account_payment.vendor.id)
    end
  end
end
