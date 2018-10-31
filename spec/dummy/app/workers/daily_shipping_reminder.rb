class DailyShippingReminder
  include Sidekiq::Worker

  def perform(vendor_id)
    vendor = Spree::Company.find(vendor_id)
    vendor.send_daily_shipping_reminder
  end
end
