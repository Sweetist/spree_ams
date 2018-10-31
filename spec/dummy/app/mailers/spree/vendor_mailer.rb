class Spree::VendorMailer < Spree::BaseMailer
  include AbstractController::Callbacks
  add_template_helper(Spree::CurrencyHelper)
  add_template_helper(DateHelper)

  before_filter :set_mail_type

  def daily_summary_email(order_ids, resend = false)
    @orders = Spree::Order.where(id: order_ids)
    return unless @orders.present?
    @order = @orders.first
    @item_qty_total = @orders.sum(:item_count)
    @order_total = @orders.sum(:total)
    vendor = @order.vendor
    # pulling all vendor users who want to receive the daily summary
    @mail_to = Spree::User.where(company_id: vendor.id).map do |recipient|
      recipient.email if recipient.daily_summary && !recipient.is_admin?
    end
    @mail_to += vendor.valid_emails if vendor.notify_daily_summary
    @mail_to = @mail_to.compact.uniq

    subject = (resend ? "[#{Spree.t(:resend)}] " : '')
    subject += "#{Spree.t('vendor_mailer.daily_summary.subject')}"
    mail(to: @mail_to, from: from_address, subject: subject) unless @mail_to.empty?
  end

  def daily_shipping_reminder_email(order_ids, resend = false)
    @orders = Spree::Order.where(id: order_ids)
    return unless @orders.present?
    @vendor = @orders.first.vendor
    # pulling all vendor users who want to receive the daily summary
    @mail_to = Spree::User.where(company_id: @vendor.id).map do |recipient|
      recipient.email if recipient.daily_shipping_reminder && !recipient.is_admin?
    end.compact
    @mail_to += @vendor.valid_emails if @vendor.notify_daily_shipping_reminder

    @mail_to = @mail_to.uniq

    subject = (resend ? "[#{Spree.t(:resend)}] " : '')
    subject += "#{Spree.t('vendor_mailer.daily_shipping_reminder.subject')}"
    mail(to: @mail_to, from: from_address, subject: subject) unless @mail_to.empty?
  end

  def confirm_email(order, resend = false)
    @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
    return unless @order.try(:send_emails?)
    vendor = @order.vendor

    @mail_to = vendor.users.map do |recipient|
      recipient.email if include_email?(@order.state, recipient)
    end
    @mail_to += vendor.valid_emails if vendor.notify_order_confirmation
    @mail_to = @mail_to.compact.uniq

    subject = (resend ? "[#{Spree.t(:resend)}] " : '')
    subject += "#{Spree.t('vendor_mailer.confirm_email.subject')} ##{@order.display_number}"
    mail(to: @mail_to, from: from_address, subject: subject) unless @mail_to.empty?
  end

  def review_order_email(order, resend = false)
    @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
    vendor = @order.vendor

    @mail_to = vendor.users.map do |recipient|
      recipient.email if include_email?(@order.state, recipient)
    end
    @mail_to += vendor.valid_emails if vendor.notify_order_review
    @mail_to = @mail_to.compact.uniq

    subject = (resend ? "[#{Spree.t(:resend)}] " : '')
    subject += "#{Spree.t('vendor_mailer.review_order.subject')} ##{@order.display_number}"
    mail(to: @mail_to, from: from_address, subject: subject) unless @mail_to.empty?
  end

  def request_access(vendor, params)
    # @email_address = params[:email]
    # @firstname = params[:firstname]
    # @lastname = params[:lastname]
    # @phone = params[:phone]
    # @company_name = params[:company]
    @vendor = vendor
    # @user = Spree::User.find_by_email(params[:email])
    # @company = @user.try(:company)
    @form_results = params || {}
    return unless vendor
    @mail_to = @vendor.valid_emails.compact.uniq

    subject = "New Account Requested via Sweet"
    mail(to: @mail_to, from: from_address, subject: subject) unless @mail_to.empty?
  end

  def discontinued_product_email(variant)
    @variant = variant.respond_to?(:id) ? variant : Spree::Variant.find(variant)
    @vendor = variant.vendor
    @mail_to = @vendor.users.map do |recipient|
      recipient.email if !recipient.is_admin? && recipient.discontinued_products
    end
    @mail_to += @vendor.valid_emails if @vendor.notify_discontinued_product

    @mail_to = @mail_to.compact.uniq
    subject = "#{@variant.full_display_name} has been #{Spree.t('variant.deactivated')}"
    mail(to: @mail_to, from: from_address, subject: subject) unless @mail_to.empty?
  end

  def low_stock_email(vendor)
    @vendor = vendor.respond_to?(:id) ? vendor : Spree::Company.friendly.find(vendor)
    @variants = @vendor.showable_variants.active.low_stock.order(:full_display_name)
    return unless @variants.present?
    @mail_to = @vendor.users.map do |recipient|
      recipient.email if !recipient.is_admin? && recipient.low_stock
    end
    @mail_to += @vendor.valid_emails if @vendor.notify_low_stock
    @mail_to = @mail_to.compact.uniq
    subject = "#{Spree.t('vendor_mailer.low_stock.subject')}"
    mail(to: @mail_to, from: from_address, subject: subject) unless @mail_to.empty?
  end

  def delete_data_email(vendor, errors)
    @vendor = vendor.respond_to?(:id) ? vendor : Spree::Company.friendly.find(vendor)
    @mail_to = @vendor.users.map do |recipient|
      recipient.email if !recipient.is_admin?
    end
    @mail_to += @vendor.valid_emails
    @mail_to = @mail_to.compact.uniq
    @errors = errors
    if errors.present?
      subject = "#{Spree.t('vendor_mailer.delete_data.subject.failure')}"
    else
      subject = "#{Spree.t('vendor_mailer.delete_data.subject.success')}"
    end
    mail(to: @mail_to, from: from_address, subject: subject) unless @mail_to.empty?
  end

  private
  # checks whether to include vendor email by comparing order state (which tells us which notification is being sent) to
  # this user's email settings for this specific notification
  # important to remember that this is the order mailer which is for customer emails, why is why these vendor emails are being
  # placed in the @copy_to array, this logic also exists in the vendor_mailer but puts the vendor emails in the @mail_to array instead
  def include_email?(state, recipient)
    return false if recipient.is_admin?
    return false if recipient.stop_all_emails
    if state == "complete" && recipient.order_confirmed
      true
    elsif state == "review" && recipient.order_review
      true
    elsif state == "invoice" && recipient.order_finalized
      true
    elsif state == "canceled" && recipient.order_canceled
      true
    #elsif state == "review" && recipient.daily_summary
    #  true
    else
      false
    end
  end

  def set_mail_type
    @mail_type = "vendor"
  end

end
