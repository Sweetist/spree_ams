module Spree
  class ContactMailer < Spree::BaseMailer
    include LiquidVarsHelper
    add_template_helper(DateHelper)
    before_action :set_mail_type

    def invite_email(vendor, contact)

      @vendor, @contact = vendor, contact

      # get email template using the name of this mailer method as the slug
      template = get_template(vendor, __method__.to_s)

      # set up @body and @options (@options includes subject, from, cc, bcc)
      setup_liquid_email(template, vendor, contact)

			unless @vendor.email.blank? || @contact.try(:email).blank?
        @contact.touch(:invited_at)
        options = merge_or_append_email_headers(@options, {to: @contact.email, from: from_address(@vendor)})
        mail(options)
      end

    end

    def contact_conflict_email(vendor, contact)
      @vendor, @contact = vendor, contact

      # grab the first customer associated with the contact
      @customer = @contact.try(:accounts).try(:first)

      @subject = "#{vendor.name} has encountered a user conflict inviting a customer to their B2B portal"
      mail(to: "help@getsweet.com", from: "help@getsweet.com" , subject: @subject)
    end

    def notify_deleted_user_email(contact_ids, company_name)
      @mail_type = "vendor"
      @company_name = company_name
      contacts = Spree::Contact.where(id: contact_ids).includes(:company, :accounts).each do |contact|
        @contact = contact
        @vendor = contact.company

        @issue = "#{contact.try(:name)} is no longer a member of #{@company_name}"
        mail(to: @vendor.valid_emails, from: "help@getsweet.com" , subject: @issue) unless @vendor.email.blank?
      end
    end

    private

    def set_mail_type
      @mail_type = "contact"
    end

    def setup_liquid_email(email_template, vendor, contact)
      @liquid_vars = set_contact_liquid_vars(vendor, contact) # set up liquid vars
      @body = email_template.render(@liquid_vars) # render email body with template + liquid var values
      @options = email_template.mail_options # get template headers, e.g., subject, from, cc, bcc headers

      # render subject with liquid var values
      if @options[:subject].present?
        @options[:subject] = Liquid::Template.parse(@options[:subject]).render(@liquid_vars) rescue @options[:subject]
      end
    end

  end
end
