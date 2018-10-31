FactoryGirl.define do
  factory :user_account, class: Spree::UserAccount do
    user
    account
  end
end
