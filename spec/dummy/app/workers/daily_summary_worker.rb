class DailySummaryWorker
  include Sidekiq::Worker

  def perform(vendor_id, start_at)
    vendor = Spree::Company.find(vendor_id)
    vendor.send_daily_summary
    vendor.update_columns(daily_summary_send_at: start_at)
  end
end
