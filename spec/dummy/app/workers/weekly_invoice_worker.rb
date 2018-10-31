class WeeklyInvoiceWorker
  include Sidekiq::Worker

  def perform(vendor_id)
    vendor = Spree::Company.find(vendor_id)

    vendor.sales_invoices.where('multi_order = ? AND end_date < ? AND start_date > ? AND confirm_sent IS NULL', true, Time.current.in_time_zone(vendor.time_zone), Time.current.in_time_zone(vendor.time_zone) - 10.days).find_each do |invoice|
      Spree::InvoiceMailer.weekly_invoice_email(invoice).deliver_now
      invoice.update_columns(confirm_sent: true)
    end

  end
end
