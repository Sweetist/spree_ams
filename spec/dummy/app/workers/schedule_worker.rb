class ScheduleWorker
  include Sidekiq::Worker

  def perform
    start_at = Time.current.beginning_of_hour

    Spree::StandingOrderSchedule.where("visible = true and skip != true and created_at is null and create_at <= ?", start_at).each do |schedule|
      Sidekiq::Client.push('class' => StandingOrderToOrderGenerator, 'queue' => 'default', 'args' => [schedule.id])
    end

    Spree::StandingOrderSchedule.where("visible = true and skip != true and processed_at is null and process_at <= ?", start_at).each do |schedule|
      Sidekiq::Client.push('class' => ProcessOrderWorker, 'queue' => 'default', 'args' => [schedule.id])
    end

    Spree::StandingOrderSchedule.where("visible = true and skip != true and reminded_at is null and remind_at <= ?", start_at).each do |schedule|
      Sidekiq::Client.push('class' => StandingOrderReminder, 'queue' => 'default', 'args' => [schedule.id])
    end

    Spree::StandingOrderSchedule.where("visible = false and deliver_at <= ?", start_at).destroy_all

    # go through each vendor and look for those whose order cutoff times were 1 hour ago
    Spree::Company.vendor_companies.where("order_cutoff_time IS NOT NULL AND order_cutoff_time != ?", '').find_each do |vendor|
      # if a vendor's cutoff time + 1 hour is equal to current hour, then we want to send a daily summary to this vendor
      # in other words, if it's currently an hour PAST the vendor's order cutoff time, we want to send a daily summary
      vendors_last_summary = vendor.daily_summary_send_at.in_time_zone(vendor.time_zone) rescue nil
      vendors_start_at = start_at.in_time_zone(vendor.time_zone)
      vendors_cutoff_time = vendor.cutoff_time_today rescue vendors_start_at.end_of_day

      #check if it is at or after cutoff time
      after_cutoff = vendors_start_at >= vendors_cutoff_time

      #check if summary has already been sent today
      summary_sent_today = vendors_last_summary.try(:to_date) == vendors_start_at.to_date

      #check if its been over 24 hours from the cutoff time since the summary was last sent
      exceeding_time_gap = vendors_last_summary && vendors_last_summary <= vendors_cutoff_time - 1.day
      next if summary_sent_today
      if after_cutoff || exceeding_time_gap
        Sidekiq::Client.push('class' => DailySummaryWorker, 'queue' => 'default', 'args' => [vendor.id, start_at])
        Sidekiq::Client.push('class' => DailyShippingReminder, 'queue' => 'default', 'args' => [vendor.id])
        Sidekiq::Client.push('class' => DailyLowStockNotification, 'queue' => 'default', 'args' => [vendor.id])
      end

      #send reminders at 9AM
      if vendors_start_at.hour >= 9
        Sidekiq::Client.push('class' => WeeklyInvoiceWorker, 'queue' => 'default', 'args' => [vendor.id]) if vendor.send_invoices
        Sidekiq::Client.push('class' => DailyInvoiceReminder, 'queue' => 'default', 'args' => [vendor.id])
      end

    end

  end
end
