class DailyInvoiceReminder
  include Sidekiq::Worker

  def perform(vendor_id)
    vendor = Spree::Company.find(vendor_id)
    today = DateHelper.sweet_today(vendor.time_zone)
    if vendor.send_invoice_reminder
      furthest_date = today + vendor.invoice_reminder_days.days
      earliest_date = today
      vendor.sales_invoices
        .where(reminder_sent_at: nil, payment_state: 'balance_due')
        .where('due_date <= ? AND due_date > ?', furthest_date, earliest_date).find_each do |invoice|
          Spree::InvoiceMailer.reminder_email(invoice).deliver_now
          invoice.update_columns(reminder_sent_at: Time.current)
      end
    end

    if vendor.send_invoice_past_due
      most_recent_date = today - vendor.invoice_past_due_days.days
      furthest_date_back = most_recent_date - 1.week
      vendor.sales_invoices
        .where(past_due_sent_at: nil, payment_state: 'balance_due')
        .where('due_date <= ? AND due_date > ?', most_recent_date, furthest_date_back).find_each do |invoice|
          Spree::InvoiceMailer.past_due_email(invoice).deliver_now
          invoice.update_columns(past_due_sent_at: Time.current)
      end
    end

  end
end
