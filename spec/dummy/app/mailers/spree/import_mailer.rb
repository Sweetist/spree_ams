module Spree
  class ImportMailer < BaseMailer
    add_template_helper(DateHelper)
    before_filter :set_mail_type

    def products_verify(import_id)
      @import = Spree::ProductImport.find(import_id)

      subject = "#{Spree.t("import_mailer.products_verify.subject_#{@import.status == 2 ? true : false}")} #{@import.file_file_name} - #{DateHelper.sweet_time(@import.created_at)}"
      mail(from: from_address,
           to: @import.company.valid_emails,
           subject: subject) if @import.company.valid_emails.first
    end

    def products_import(import_id)
      @import = Spree::ProductImport.find(import_id)

      subject = "#{Spree.t("import_mailer.products_import.subject_#{@import.status == 6 ? true : false}")} #{@import.file_file_name} - #{DateHelper.sweet_time(@import.created_at)}"

      mail(from: from_address,
           to: @import.company.valid_emails,
           subject: subject) if @import.company.valid_emails.first
    end

    def customers_verify(import_id)
      @import = Spree::CustomerImport.find(import_id)

      subject = "#{Spree.t("import_mailer.customers_verify.subject_#{@import.status == 2 ? true : false}")} #{@import.file_file_name} - #{DateHelper.sweet_time(@import.created_at)}"
      mail(from: from_address,
           to: @import.company.valid_emails,
           subject: subject) if @import.company.valid_emails.first
    end

    def customers_import(import_id)
      @import = Spree::CustomerImport.find(import_id)

      subject = "#{Spree.t("import_mailer.customers_import.subject_#{@import.status == 6 ? true : false}")} #{@import.file_file_name} - #{DateHelper.sweet_time(@import.created_at)}"

      mail(from: from_address,
           to: @import.company.valid_emails,
           subject: subject) if @import.company.valid_emails.first
    end

    def vendors_verify(import_id)
      @import = Spree::VendorImport.find(import_id)
      subject = "#{Spree.t("import_mailer.vendors_verify.subject_#{@import.status == 2 ? true : false}")} #{@import.file_file_name} - #{DateHelper.sweet_time(@import.created_at)}"
      mail(from: from_address,to: @import.company.valid_emails,subject: subject) if @import.company.valid_emails.first
    end

    def vendors_import(import_id)
      @import = Spree::VendorImport.find(import_id)
      subject = "#{Spree.t("import_mailer.vendors_import.subject_#{@import.status == 6 ? true : false}")} #{@import.file_file_name} - #{DateHelper.sweet_time(@import.created_at)}"
      mail(from: from_address,
           to: @import.company.valid_emails,
           subject: subject) if @import.company.valid_emails.first
    end

    def set_mail_type
      @mail_type = "vendor"
    end
  end
end
