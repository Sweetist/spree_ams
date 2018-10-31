FactoryGirl.define do
  factory :permission_group, class: Spree::PermissionGroup do
    name 'basic_permissions'
    company
  end
end
