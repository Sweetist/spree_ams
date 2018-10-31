FactoryGirl.define do
  factory :spree_applied_credit, :class => 'Spree::AppliedCredit' do
    credit_memo ""
account_payment ""
amount "9.99"
  end

end
