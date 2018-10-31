module Spree
  class StandingOrderMailer < BaseMailer
    add_template_helper(Spree::CurrencyHelper)
    add_template_helper(DateHelper)
    before_filter :set_mail_type

    def reminder_email(schedule_id)
      @schedule = Spree::StandingOrderSchedule.find(schedule_id)
      @order = @schedule.standing_order
      @account = Spree::Account.where(id: @order.try(:account_id)).first
      @address = @order.account.shipping_addresses
      @mail_to, @copy_to = set_recipients(@order, 'reminder')
      subject = "#{Spree.t('standing_order_mailer.reminder_email.subject1')} #{@order.vendor.name} #{Spree.t('standing_order_mailer.reminder_email.subject2')} #{DateHelper.sweet_date(@schedule.deliver_at, @schedule.standing_order.vendor.time_zone)}"
      if @mail_to.empty? && @order.vendor.send_mail_to_my_company
        @mail_to = @order.vendor.valid_emails
      end
      mail(from: from_address(@order.vendor),
           to: @mail_to,
           cc: @copy_to,
           subject: subject) unless @mail_to.empty?
    end

    def so_update_email(tracker_id)
      @tracker = Spree::StandingOrderTracker.find(tracker_id)
      @order = @tracker.standing_order
      @account = Spree::Account.where(id: @order.try(:account_id)).first
      @address = @order.account.shipping_addresses
      @mail_to, @copy_to = set_recipients(@order, 'update')
      @mail_to = [] unless @order.vendor.send_so_update_email
      subject = "#{Spree.t('standing_order_mailer.changes_email.subject1')} #{@order.name} #{Spree.t('standing_order_mailer.changes_email.subject2')}"
      if @mail_to.empty? && @order.vendor.send_mail_to_my_company
        @mail_to = @order.vendor.valid_emails
      end
      mail(from: from_address,
          to: @mail_to,
          cc: @copy_to,
          subject: subject) unless @mail_to.empty?
    end

    private

    def set_recipients(order, mail_type)
      # grab all user emails associated with the account
      mail_to = order.account.collect_customer_emails

      # next, grab user emails and communication settings associated with the vendor
      # then go through and check which vendor users are signed up to receive emails (checks settings vs order state / notification being sent)
      copy_to = order.vendor.users.map do |recipient|
        case mail_type
        when 'update'
          recipient.email unless recipient.is_admin? || recipient.stop_all_emails || !recipient.so_edited
        when 'reminder'
          recipient.email unless recipient.is_admin? || recipient.stop_all_emails || !recipient.so_reminder
        end
      end
      copy_to += order.vendor.valid_emails if order.vendor.send_cc_to_my_company
      [mail_to.compact.uniq, copy_to.compact.uniq]
    end

    def set_mail_type
      @mail_type = "order"
    end

  end
end
