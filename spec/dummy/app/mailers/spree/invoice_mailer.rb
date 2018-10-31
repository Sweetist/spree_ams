class Spree::InvoiceMailer < Spree::BaseMailer
  include AbstractController::Callbacks
  include LiquidVarsHelper
  add_template_helper(Spree::CurrencyHelper)
  add_template_helper(DateHelper)

  before_action :set_mail_type

  def reminder_email(invoice, override_account_email_settings = false, dev_preview = false)
    return unless load_invoice(invoice) && @invoice.balance_due?

    vendor = @invoice.vendor

    # get email template using the name of this mailer method as the slug
    template = get_template(vendor, __method__.to_s, dev_preview)

    # set up @body and @options (@options includes subject, from, cc, bcc)
    setup_liquid_email(template)

    # merge liquid @options with original mail_to and copy_to arrays and return to options hash
    options = set_liquid_mail_options(@invoice, dev_preview, override_account_email_settings)

    #attach invoice
    filename = "#{@invoice.vendor.name.squish.downcase.tr(" ","_")}_#{@invoice.number}_#{@invoice.end_date.strftime('%Y_%m_%d')}.pdf"
    attachments[filename] = @invoice.pdf_invoice_for_invoice.pdf

    if options[:to].present? && (vendor.send_invoice_reminder || vendor.send_mail_to_my_company || dev_preview)
      mail(options)
      @invoice.update_columns(reminder_sent_at: Time.current) if vendor.send_invoice_reminder
    end
  end

  def past_due_email(invoice, override_account_email_settings = false, dev_preview = false)
    return unless load_invoice(invoice) && @invoice.balance_due?

    vendor = @invoice.vendor

    # get email template using the name of this mailer method as the slug
    template = get_template(vendor, __method__.to_s, dev_preview)

    # set up @body and @options (@options includes subject, from, cc, bcc)
    setup_liquid_email(template)

    # merge liquid @options with original mail_to and copy_to arrays and return to options hash
    options = set_liquid_mail_options(@invoice, dev_preview, override_account_email_settings)

    #attach inovice
    filename = "#{@invoice.vendor.name.squish.downcase.tr(" ","_")}_#{@invoice.number}_#{@invoice.end_date.strftime('%Y_%m_%d')}.pdf"
    attachments[filename] = @invoice.pdf_invoice_for_invoice.pdf

    if options[:to].present? && (vendor.send_invoice_past_due || vendor.send_mail_to_my_company || dev_preview)
      mail(options)
      @invoice.update_columns(past_due_sent_at: Time.current) if vendor.send_invoice_past_due
    end
  end

  def weekly_invoice_email(invoice, override_account_email_settings = false, resend = false, dev_preview = false)
    return unless load_invoice(invoice)

    vendor = @invoice.vendor

    # get email template using the name of this mailer method as the slug
    template = get_template(vendor, __method__.to_s, dev_preview)

    # set up @body and @options (@options includes subject, from, cc, bcc)
    setup_liquid_email(template)

    mail_to = @invoice.account.collect_customer_emails({override_account_email_settings: override_account_email_settings})
    mail_to = [] unless @invoice.vendor.send_weekly_invoice_email
    if mail_to.empty? && @invoice.vendor.send_mail_to_my_company
      mail_to = @invoice.vendor.valid_emails
    end
    copy_to = @invoice.vendor.send_cc_to_my_company ? @invoice.vendor.valid_emails : []

    mail_to = mail_to.compact.uniq
    copy_to = copy_to.compact.uniq

    if mail_to.present?
      if copy_to.present?
        options = merge_or_append_email_headers(@options, {to: mail_to, from: from_address(@invoice.vendor), cc: copy_to})
      else
        options = merge_or_append_email_headers(@options, {to: mail_to, from: from_address(@invoice.vendor)})
      end
      update_invoice_sent_at
    elsif @invoice.vendor.send_mail_to_my_company
      options = merge_or_append_email_headers(@options, {to: @invoice.vendor.valid_emails, from: from_address(@invoice.vendor)})
    elsif dev_preview # let's preview the mailer even if there's no mail_to
      options = merge_or_append_email_headers(@options, {to: "preview_test@getsweet.com", from: from_address(@invoice.vendor), cc: copy_to})
    end

    filename = "#{@invoice.account.name.squish.downcase.tr(" ","_")}_#{@invoice.end_date.strftime('%Y_%m_%d')}.pdf"
    attachments[filename] = @invoice.pdf_invoice_for_invoice.pdf

    if options[:to].present? && (vendor.send_weekly_invoice_email || vendor.send_cc_to_my_company || dev_preview)
      mail(options)
      update_invoice_sent_at if vendor.send_weekly_invoice_email
    end
  end

  private

  def load_invoice(invoice)
    @invoice = invoice.respond_to?(:id) ? invoice : Spree::Invoice.find(invoice) rescue nil
    @order = @invoice.try(:orders).try(:first)

    @invoice.present? && @invoice.orders.any?{ |o| o.send_emails? }
  end

  def set_liquid_mail_options(invoice, dev_preview = false, override_account_email_settings = false)
    # grab all user emails associated with the customer

    mail_to = invoice.account.collect_customer_emails({override_account_email_settings: override_account_email_settings})

    # next, grab user emails and communication settings associated with the vendor
    # then go through and check which vendor users are signed up to receive emails (checks settings vs order state / notification being sent)
    copy_to = invoice.vendor.users.map do |recipient|
      recipient.email if !recipient.is_admin? && !recipient.stop_all_emails && recipient.order_finalized
    end
    copy_to += invoice.vendor.valid_emails if invoice.vendor.send_cc_to_my_company

    mail_to = mail_to.compact.uniq
    copy_to = copy_to.compact.uniq

    if mail_to.present?
      if copy_to.present?
        options = merge_or_append_email_headers(@options, {to: mail_to, from: from_address(invoice.vendor), cc: copy_to})
      else
        options = merge_or_append_email_headers(@options, {to: mail_to, from: from_address(invoice.vendor)})
      end
      update_invoice_sent_at
    elsif invoice.vendor.send_mail_to_my_company
      options = merge_or_append_email_headers(@options, {to: invoice.vendor.valid_emails, from: from_address(invoice.vendor)})
    elsif dev_preview # let's preview the mailer even if there's no mail_to
      options = merge_or_append_email_headers(@options, {to: "preview_test@getsweet.com", from: from_address(invoice.vendor), cc: copy_to})
    else
      options = merge_or_append_email_headers(@options, {from: from_address(invoice.vendor)})
    end

    return options
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

  def set_mail_type
    @mail_type = "invoice"
  end

  def update_invoice_sent_at
    @invoice.orders.where(invoiced_at: nil).update_all(invoiced_at: Time.current)
    @invoice.orders.update_all(invoice_sent_at: Time.current)
  end

end
