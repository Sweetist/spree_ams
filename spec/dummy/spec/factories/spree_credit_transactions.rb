FactoryGirl.define do
  factory :spree_credit_transaction, :class => 'Spree::CreditTransaction' do
    amount "9.99"
credit_transactionable ""
  end

end
