FactoryGirl.define do
  factory :standing_order_schedule, class: Spree::StandingOrderSchedule do
    deliver_at { Date.current }
    visible true
    standing_order
  end
end
