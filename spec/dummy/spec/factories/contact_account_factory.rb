FactoryGirl.define do
  factory :contact_account, class: Spree::ContactAccount do
    contact
    account
  end
end
