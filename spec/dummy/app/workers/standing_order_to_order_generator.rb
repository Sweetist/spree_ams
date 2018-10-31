class StandingOrderToOrderGenerator
  include Sidekiq::Worker

  def perform(schedule_id)
    schedule = Spree::StandingOrderSchedule.lock.find(schedule_id)
    schedule.standing_order.recalculate_dates((Date.current + 3.months).beginning_of_month - 2.days)
    unless schedule.skip or schedule.created_at
      schedule.generate_order!
    end
  rescue ActiveRecord::RecordNotFound
    true # moving on if schedule has been removed from DB
  end
end
