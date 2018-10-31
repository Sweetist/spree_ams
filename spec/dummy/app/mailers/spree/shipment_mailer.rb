class Spree::ShipmentMailer < Spree::BaseMailer
  include LiquidVarsHelper
  add_template_helper(Spree::CurrencyHelper)
  add_template_helper(DateHelper)

  before_action :set_mail_type

  def shipped_email(shipment, resend = false, dev_preview = false)
    return unless load_shipment(shipment)

    vendor = @order.vendor
    # check if need to attach inovice
    @send_as_invoice = vendor.send_shipped_email && vendor.send_shipped_email_invoice

    # get email template using the name of this mailer method as the slug
    template = get_template(vendor, __method__.to_s, dev_preview)

    # set up @body and @options (@options includes subject, from, cc, bcc)
    setup_liquid_email(template)

    # merge liquid @options with original mail_to array and return to options hash
    options = set_liquid_mail_options(@order, @order.state, dev_preview)

    @ordered_item_count = @order.line_items.sum(:ordered_qty)

    if @send_as_invoice
      ensure_invoice
      filename = "#{@invoice.account.name.squish.downcase.tr(" ","_")}_#{@invoice.end_date.strftime('%Y_%m_%d')}.pdf"
      attachments[filename] = @invoice.pdf_invoice_for_invoice.pdf
    end

    if options[:to].empty? && @order.vendor.send_mail_to_my_company
      options[:to] = @order.vendor.valid_emails
    end

    if (!options[:to].blank? && vendor.send_shipped_email) || dev_preview
      mail(options)
    end

  end

  def received_email(shipment, resend = false)
    return unless load_shipment(shipment)

    @ordered_item_count = @order.line_items.sum(:ordered_qty)
    @shipped_item_count = @order.line_items.sum(:shipped_qty)
    @mail_to_account, @mail_to_vendor = set_recipients(@order, @shipment.state)
    subject = (resend ? "[#{Spree.t(:resend)}] " : '')
    subject += "#{Spree.t('order_mailer.confirm_email.subject')} #{@order.vendor.name} (##{@order.display_number})"
    if @mail_to_account.empty? && @order.vendor.send_mail_to_my_company
      @mail_to_account = @order.vendor.valid_emails
    end
    mail(to: @mail_to_vendor, from: from_address(@order.vendor), subject: subject) unless @mail_to_account.empty?
  end

  private

  def set_recipients(order, state)
    mail_to_account = order.account.collect_customer_emails({email_type: :shipment})

    mail_to_vendor = order.vendor.users.map do |recipient|
      recipient.email if include_email?(state, recipient)
    end
    mail_to_vendor += order.vendor.valid_emails if order.vendor.send_cc_to_my_company

    [mail_to_account.compact.uniq, mail_to_vendor.compact.uniq]
  end

  def set_liquid_mail_options(order, state, dev_preview = false, errors = nil)
    # grab all user emails associated with the customer

    mail_to = order.account.collect_customer_emails({email_type: :shipment})

    mail_to = mail_to.compact.uniq

    if mail_to.present?
      options = merge_or_append_email_headers(@options, {to: mail_to, from: from_address(@order.vendor)})
      update_invoice_sent_at
    elsif @order.vendor.send_mail_to_my_company
      options = merge_or_append_email_headers(@options, {to: @order.vendor.valid_emails, from: from_address(@order.vendor)})
    elsif dev_preview # let's preview the mailer even if there's no mail_to
      options = merge_or_append_email_headers(@options, {to: "preview_test@getsweet.com", from: from_address(@order.vendor)})
    else
      options = merge_or_append_email_headers(@options, {from: from_address(@order.vendor)})
    end

    return options
  end

  def include_email?(state, recipient)
    return false if recipient.is_admin?
    return false if recipient.stop_all_emails
    if state == "received" && recipient.order_received
      true
    else
      false
    end
  end

  def load_shipment(shipment)
    @shipment = shipment.respond_to?(:id) ? shipment : Spree::Shipment.find(shipment) rescue nil
    @order = @shipment.try(:order)
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

  def set_mail_type
    @mail_type = "order"
  end


  def setup_liquid_email(email_template)
    @liquid_vars = set_shipment_liquid_vars(@shipment) # set up liquid vars
    if @order && !@liquid_vars.blank?
      @liquid_vars = @liquid_vars.merge(set_order_liquid_vars(@order))
    else
      @liquid_vars = set_order_liquid_vars(@order)
    end
    @liquid_vars = @liquid_vars.merge(set_invoice_liquid_vars(@invoice)) if @invoice

    @body = email_template.render(@liquid_vars) # render email body with template + liquid var values
    @options = email_template.mail_options # get template headers, e.g., subject, from, cc, bcc headers

    # render subject with liquid var values
    if @options[:subject].present?
      @options[:subject] = Liquid::Template.parse(@options[:subject]).render(@liquid_vars) rescue @options[:subject]
    end
  end

end
