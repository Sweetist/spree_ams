class StandingOrderReminder
  include Sidekiq::Worker

  def perform(schedule_id)
    schedule = Spree::StandingOrderSchedule.find(schedule_id)
    schedule.standing_order.recalculate_dates((Date.current + 3.months).beginning_of_month - 2.days)
    unless schedule.skip or schedule.reminded_at
      schedule.remind!
    end
  rescue ActiveRecord::RecordNotFound
    true # moving on if schedule has been removed from DB
  end
end
