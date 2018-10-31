Spree::BaseMailer.class_eval do

  def self.inherited(subclass)
    subclass.default template_path: "mailers/#{subclass.name.to_s.underscore}"
  end

  def from_address(company = nil)
    company.try(:valid_emails).try(:first) || Spree::Store.current.mail_from_address
  end

  # method to find and return template object
  def get_template(company, slug, dev_preview = false)
    if dev_preview
      # if it's a preview, let's just grab any vendor's template
      email_template = Spree::EmailTemplate.find_by_slug(slug)
    else
      email_template = company.email_templates.find_by_slug(slug)

      # if email template wasn't previously set up but mailer is trying to send, let's create it
      if email_template.nil?
        email_template = company.find_or_create_email_template(self.class.name, slug)
      end
    end
    return email_template
  end

  # method to append values of one hash of email headers with another
  # using a regular hash merge call overrides existing hash values
  def merge_or_append_email_headers(options, new_options)

    options[:to] = [options[:to], new_options[:to]].flatten.reject(&:blank?).join(', ')
    options[:from] = [options[:from], new_options[:from]].flatten.reject(&:blank?).join(', ')
    options[:cc] = [options[:cc], new_options[:cc]].flatten.reject(&:blank?).join(', ')
    options[:bcc] = [options[:bcc], new_options[:bcc]].flatten.reject(&:blank?).join(', ')

    return options
  end

end
