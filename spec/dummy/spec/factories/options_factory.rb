FactoryGirl.define do
  factory :option_value, class: Spree::OptionValue do
    sequence(:name) { |n| "Size-#{n}" }
    sequence(:presentation) { |n| "Size-#{n}" }
    vendor { |v| Spree::Company.first || v.association(:vendor) }

    option_type
  end

  factory :option_type, class: Spree::OptionType do
    sequence(:name) { |n| "foo-size-#{n}" }
    sequence(:presentation) { |n| "Foo Size #{n}" }
    vendor { |v| Spree::Company.first || v.association(:vendor) }
  end
end
