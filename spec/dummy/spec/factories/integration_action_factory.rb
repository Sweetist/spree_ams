FactoryGirl.define do
  factory :integration_action, class: Spree::IntegrationAction do
    integration_item
    status 0
    processed_at Time.current
  end
end
