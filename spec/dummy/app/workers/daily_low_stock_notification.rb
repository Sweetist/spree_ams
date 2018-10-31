class DailyLowStockNotification
  include Sidekiq::Worker

  def perform(vendor_id)
    vendor = Spree::Company.find(vendor_id)
    vendor.send_daily_low_stock_notification
  end
end
