class Spree::OrderMailer < Spree::BaseMailer
  include AbstractController::Callbacks
  include LiquidVarsHelper
  add_template_helper(Spree::CurrencyHelper)
  add_template_helper(DateHelper)

  before_action :set_mail_type

  def confirm_email(order, resend = false, dev_preview = false)
    return unless load_order(order)

    vendor = @order.vendor

    # get email template using the name of this mailer method as the slug
    template = get_template(vendor, __method__.to_s, dev_preview)

    # set up @body and @options (@options includes subject, from, cc, bcc)
    setup_liquid_email(template)

    # merge liquid @options with original mail_to and copy_to arrays and return to options hash
    options = set_liquid_mail_options(@order, @order.state, false, dev_preview)

    if ((@order.created_by_customer? && vendor.send_confirm_email) || dev_preview)
      mail(options) unless options[:to].blank?
    end
  end

  def approved_email(order, resend = false, dev_preview = false)
    return unless load_order(order)

    vendor = @order.vendor
    @send_as_invoice = vendor.send_approved_email && vendor.send_approved_email_invoice

    # get email template using the name of this mailer method as the slug
    template = get_template(vendor, __method__.to_s, dev_preview)

    # set up @body and @options (@options includes subject, from, cc, bcc)
    setup_liquid_email(template)

    # merge liquid @options with original mail_to and copy_to arrays and return to options hash
    options = set_liquid_mail_options(@order, @order.state, false, dev_preview)


    # check if need to attach invoice
    if @send_as_invoice
      ensure_invoice
      filename = "#{@invoice.account.name.squish.downcase.tr(" ","_")}_#{@invoice.end_date.strftime('%Y_%m_%d')}.pdf"
      attachments[filename] = @invoice.pdf_invoice_for_invoice.pdf
    end

    if vendor.send_approved_email_b2b_and_standing_only
      should_send = @order.created_by_customer? \
        || (@order.is_from_standing_order? && vendor.auto_approve_orders)
    else
      should_send = true
    end

    if ((vendor.send_approved_email && should_send) || dev_preview)
      mail(options) unless options[:to].blank?
    end
  end

  def review_order_email(order, resend = false, dev_preview = false)
    return unless load_order(order)

    vendor = @order.vendor

    # get email template using the name of this mailer method as the slug
    template = get_template(vendor, __method__.to_s, dev_preview)

    # set up @body and @options (@options includes subject, from, cc, bcc)
    setup_liquid_email(template)

    # merge liquid @options with original mail_to and copy_to arrays and return to options hash
    options = set_liquid_mail_options(@order, @order.state, false, dev_preview)

    if (vendor.send_review_order_email || dev_preview)
      mail(options) unless options[:to].blank?
    end
  end

  def cancel_email(order, resend = false, dev_preview = false)
    return unless load_order(order)

    vendor = @order.vendor

    # get email template using the name of this mailer method as the slug
    template = get_template(vendor, __method__.to_s, dev_preview)

    # set up @body and @options (@options includes subject, from, cc, bcc)
    setup_liquid_email(template)

    # merge liquid @options with original mail_to and copy_to arrays and return to options hash
    options = set_liquid_mail_options(@order, @order.state, false, dev_preview)

    if (vendor.send_cancel_email || dev_preview)
      mail(options) unless options[:to].blank?
    end
  end

  def final_invoice_email(order, override_account_email_settings = false, force_send = false, dev_preview = false)
    return unless load_order(order)
    return if (@invoice.try(:confirm_sent) || @order.invoice_sent_at) && !force_send

    vendor = @order.vendor
    # This is last step, no overrides here so need to redefine
    @send_as_invoice = true

    # get email template using the name of this mailer method as the slug
    template = get_template(vendor, __method__.to_s, dev_preview)

    # set up @body and @options (@options includes subject, from, cc, bcc)
    setup_liquid_email(template)

    # merge liquid @options with original mail_to and copy_to arrays and return to options hash
    options = set_liquid_mail_options(@order, @order.state, override_account_email_settings, dev_preview)


    # check if need to attach inovice
    if vendor.send_final_invoice_email_invoice
      ensure_invoice
      filename = "#{@invoice.account.name.squish.downcase.tr(" ","_")}_#{@invoice.end_date.strftime('%Y_%m_%d')}.pdf"
      attachments[filename] = @order.invoice.pdf_invoice_for_invoice.pdf
    end
    if (vendor.send_final_invoice_email || force_send || dev_preview)
      mail(options) unless options[:to].blank?
    end
  end

  def unapprove(order, resend = false, dev_preview = false)
    return unless load_order(order)

    vendor = @order.vendor

    # get email template using the name of this mailer method as the slug
    template = get_template(vendor, __method__.to_s, dev_preview)

    # set up @body and @options (@options includes subject, from, cc, bcc)
    setup_liquid_email(template)

    # merge liquid @options with original mail_to and copy_to arrays and return to options hash
    options = set_liquid_mail_options(@order, @order.state, false, dev_preview)

    if (vendor.send_unapprove_email || dev_preview)
      mail(options) unless options[:to].blank?
    end
  end

  ########################################
  # BELOW MAILERS ARE NOT LIQUID-ENABLED #
  ########################################

  def so_create_email(order, so_name, resend = false, errors = [])
    return unless load_order(order)

    @so_name = so_name
    @errors = errors
    @mail_to, @copy_to = set_recipients(@order, @order.state)
    @mail_to = [] unless @order.vendor.send_so_create_email
    subject = (resend ? "[#{Spree.t(:resend)}] " : '')
    subject += "#{Spree.t('order_mailer.so_create_email.subject1')} #{@order.vendor.name} #{Spree.t('order_mailer.so_create_email.subject2')} #{DateHelper.sweet_date(@order.delivery_date, @order.vendor.time_zone)}"

    send_mail(subject, false, false)
  end

  def so_create_error_email(order, so_name, resend = false, errors = [])
    return unless load_order(order)

    @so_name = so_name
    @errors = errors
    @mail_to, @copy_to = set_recipients(@order, @order.state)
    @mail_to = [] unless @order.vendor.send_so_create_error_email
    subject = (resend ? "[#{Spree.t(:resend)}] " : '')
    subject += "#{Spree.t('order_mailer.so_create_error_email.subject1')} #{@order.vendor.name} #{Spree.t('order_mailer.so_create_error_email.subject2')} #{DateHelper.sweet_date(@order.delivery_date, @order.vendor.time_zone)}"

    send_mail(subject, false, true)
  end

  def so_process_error_email(order, so_name, errors = [])
    return unless load_order(order)

    @so_name = so_name
    @errors = errors
    @mail_to, @copy_to = set_recipients(@order, @order.state, @errors)
    @mail_to = [] unless @order.vendor.send_so_process_error_email
    subject = "#{Spree.t('order_mailer.so_process_error_email.subject1')} #{@order.vendor.name} #{Spree.t('order_mailer.so_process_error_email.subject2')} #{DateHelper.sweet_date(@order.delivery_date, @order.vendor.time_zone)}"

    send_mail(subject, false, true)
  end

  def purchase_order_submit_email(order, resend = false)
    @mail_type = "purchase_order"
    @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
    return unless @order.send_emails?

    @mail_to, @copy_to = set_po_recipients(@order, @order.state)

    subject = (resend ? "[#{Spree.t(:resend)}] " : '')
    subject += "#{Spree.t('order_mailer.purchase_order_submit_email.subject')} #{@order.customer.name} (##{@order.po_display_number})"

    filename = "#{@order.account.name.squish.downcase.tr(" ","_")}_purchase_order_#{@order.po_display_number}.pdf"
    attachments[filename] = @order.pdf_purchase_order_for_order.pdf
    mail(to: @mail_to, from: from_address(@order.customer), subject: subject) unless @mail_to.blank?
  end

  def purchase_order_resubmit_email(order, resend = false)
    @mail_type = "purchase_order"
    @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
    return unless @order.send_emails?

    @mail_to, @copy_to = set_po_recipients(@order, @order.state)

    subject = (resend ? "[#{Spree.t(:resend)}] " : '')
    subject += "#{Spree.t('order_mailer.purchase_order_resubmit_email.subject1')} #{@order.po_display_number} #{Spree.t('order_mailer.purchase_order_resubmit_email.subject2')} #{@order.customer.name}"
    filename = "#{@order.account.name.squish.downcase.tr(" ","_")}_purchase_order_#{@order.po_display_number}.pdf"
    attachments[filename] = @order.pdf_purchase_order_for_order.pdf
    mail(to: @mail_to, from: from_address(@order.customer), subject: subject) unless @mail_to.empty?
  end

  def purchase_order_cancel_email(order, resend = false)
    @mail_type = "purchase_order"
    @order = order.respond_to?(:id) ? order : Spree::Order.find(order)
    return unless @order.send_emails?

    @mail_to, @copy_to = set_recipients(@order, @order.state)

    subject = (resend ? "[#{Spree.t(:resend)}] " : '')
    subject += "#{Spree.t('order_mailer.purchase_order_cancel_email.subject1')} ##{@order.po_display_number} #{Spree.t('order_mailer.purchase_order_cancel_email.subject2')} #{@order.customer.name}"

    mail(to: @mail_to, from: from_address(@order.customer), subject: subject) unless @mail_to.empty?
  end

  private

  # FOR NOW, WE ARE NOT GIVING EMAIL COMMUNICATION PREFERENCES TO CUSTOMER
  # SO THE BELOW CODE JUST SERVES TO PULL ALL CUSTOMER EMAILS
  # also not using @copy_to
  def set_recipients(order, state, errors = nil)
    # grab all user emails associated with the customer

    mail_to = order.account.collect_customer_emails

    # next, grab user emails and communication settings associated with the vendor
    # then go through and check which vendor users are signed up to receive emails (checks settings vs order state / notification being sent)
    copy_to = order.vendor.users.map do |recipient|
      recipient.email if include_vendor_email?(order, state, recipient, errors)
    end
    copy_to += order.vendor.valid_emails if order.vendor.send_cc_to_my_company || errors.present?

    [mail_to.compact.uniq, copy_to.compact.uniq]
  end

  def set_liquid_mail_options(order, state, override_account_email_settings = false, dev_preview = false, errors = nil)
    # grab all user emails associated with the customer

    mail_to = order.account.collect_customer_emails({override_account_email_settings:override_account_email_settings})

    # next, grab user emails and communication settings associated with the vendor
    # then go through and check which vendor users are signed up to receive emails (checks settings vs order state / notification being sent)
    copy_to = order.vendor.users.map do |recipient|
      recipient.email if include_vendor_email?(order, state, recipient, errors)
    end
    copy_to += order.vendor.valid_emails if order.vendor.send_cc_to_my_company || errors.present?

    mail_to = mail_to.compact.uniq
    copy_to = copy_to.compact.uniq

    if mail_to.present?
      if copy_to.present?
        options = merge_or_append_email_headers(@options, {to: mail_to, from: from_address(@order.vendor), cc: copy_to})
      else
        options = merge_or_append_email_headers(@options, {to: mail_to, from: from_address(@order.vendor)})
      end
      update_invoice_sent_at
    elsif @order.vendor.send_mail_to_my_company
      options = merge_or_append_email_headers(@options, {to: @order.vendor.valid_emails, from: from_address(@order.vendor)})
    elsif dev_preview # let's preview the mailer even if there's no mail_to
      options = merge_or_append_email_headers(@options, {to: "preview_test@getsweet.com", from: from_address(@order.vendor), cc: copy_to})
    else
      options = merge_or_append_email_headers(@options, {from: from_address(@order.vendor)})
    end

    return options
  end

  def set_po_recipients(order, state, errors = nil)
    mail_to = []
    if order.account.send_purchase_orders_emails
      mail_to = order.vendor.users.map do |recipient|
        recipient.email unless recipient.is_admin?
      end

      mail_to += order.account.valid_emails
    end

    copy_to = []

    [mail_to.compact.uniq, copy_to.compact.uniq]
  end


  # checks whether to include vendor email by comparing order state (which tells us which notification is being sent) to
  # this user's email settings for this specific notification
  # important to remember that this is the order mailer which is for customer emails, why is why these vendor emails are being
  # placed in the @copy_to array, this logic also exists in the vendor_mailer but puts the vendor emails in the @mail_to array instead
  def include_vendor_email?(order, state, recipient, errors = nil)
    return false if recipient.is_admin?
    return false if recipient.stop_all_emails
    if state == "complete" && recipient.order_confirmed
      true
    elsif state == "approved" && recipient.order_approved
      true
    elsif state == "received" && recipient.order_received
      true
    elsif state == "review" && recipient.order_review
      true
    elsif state == "invoice" && recipient.order_finalized
      true
    elsif state == "canceled" && recipient.order_canceled
      true
    elsif errors.present?
      recipient.so_create_error
    #elsif state == "review" && recipient.daily_summary
    #  true
    else
      false
    end
  end

  def set_mail_type
    @mail_type = "order"
  end

  def load_order(order)
    @order = order.respond_to?(:id) ? order : Spree::Order.friendly.find(order) rescue nil
    @invoice = @order.try(:invoice)

    @order.try(:send_emails?)
  end

  def ensure_invoice
    if @invoice.nil?
      raise Exception.new("Invoice not found for order #{@order.number}")
    end
  end

  def update_invoice_sent_at
    @order.update_columns(invoice_sent_at: Time.current) if @send_as_invoice
  end

  def send_mail(subject, should_update_invoice_sent = true, include_cc = false)
    if @mail_to.empty? && @order.vendor.send_mail_to_my_company
      @alternate_mail_to = @order.vendor.valid_emails
    end

    if @mail_to.present?
      if include_cc && @copy_to.present?
        mail(to: @mail_to, from: from_address(@order.vendor), subject: subject)
      else
        mail(to: @mail_to, cc: @copy_to, from: from_address(@order.vendor), subject: subject)
      end
      update_invoice_sent_at if should_update_invoice_sent
    elsif @copy_to.present?
      mail(to: @copy_to, from: from_address(@order.vendor), subject: subject)
    elsif @alternate_mail_to.present?
      mail(to: @alternate_mail_to, from: from_address(@order.vendor), subject: subject)
    end
  end

  def setup_liquid_email(email_template)
    @liquid_vars = set_order_liquid_vars(@order) # set up liquid vars
    @liquid_vars = @liquid_vars.merge(set_invoice_liquid_vars(@invoice)) if @invoice

    @body = email_template.render(@liquid_vars) # render email body with template + liquid var values
    @options = email_template.mail_options # get template headers, e.g., subject, from, cc, bcc headers

    # render subject with liquid var values
    if @options[:subject].present?
      @options[:subject] = Liquid::Template.parse(@options[:subject]).render(@liquid_vars) rescue @options[:subject]
    end
  end

end
