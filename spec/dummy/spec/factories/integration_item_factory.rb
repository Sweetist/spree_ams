FactoryGirl.define do
  factory :integration_item, class: Spree::IntegrationItem do
    integration_key 'qbo'
    integration_type 'accounting'
    vendor
  end
end
