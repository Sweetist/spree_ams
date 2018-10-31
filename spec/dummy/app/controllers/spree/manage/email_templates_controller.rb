module Spree
  module Manage
    class EmailTemplatesController < Spree::Manage::BaseController
      include LiquidVarsHelper

      def edit
        @email_template = current_vendor.email_templates.find(params[:id])
        @attach_pdf_option_exists = @attach_pdf = false
        setup_attach_pdf_vars
      end

      def update
        @email_template = current_vendor.email_templates.find(params[:id])

        case @email_template.slug
        when "approved_email"
          current_vendor.send_approved_email_invoice = params[:template][:attach_pdf].to_bool
          current_vendor.save
        when "shipped_email"
          current_vendor.send_shipped_email_invoice = params[:template][:attach_pdf].to_bool
          current_vendor.save
        when "final_invoice_email"
          current_vendor.send_final_invoice_email_invoice = params[:template][:attach_pdf].to_bool
          current_vendor.save
        end

        if @email_template.update(email_template_params)
          flash[:success] = "Email template updated successfully"
          if params[:commit] == "Save"
            redirect_to edit_manage_outgoing_communications_path
          else
            setup_attach_pdf_vars
            redirect_to edit_manage_email_template_path(@email_template)
          end
        else
          flash.now[:error] = "Could not update email template"
          setup_attach_pdf_vars
          render :edit
        end
      end

      def restore_template

        @email_template = current_vendor.email_templates.find(params[:email_template_id])
        @email_template.restore_original_template

        if @email_template.save
          flash[:success] = "Original template restored"
          redirect_to edit_manage_email_template_path(@email_template)
        else
          flash.now[:error] = "Could not restore original email template"
          setup_attach_pdf_vars
          render :edit
        end
      end

      def preview_mailer

        @email_template = current_vendor.email_templates.find_by_id(params[:email_template_id])

        case @email_template.slug

        when 'invite_email'
          @liquid_vars = set_contact_liquid_vars(current_vendor)
          @mail_type = 'contact'
          @mailer_path = 'contact_mailer/invite_email'
        when 'confirm_email'
          @liquid_vars = set_order_liquid_vars
          @mail_type = 'order'
          @mailer_path = 'order_mailer/confirm_email'
        when 'approved_email'
          @liquid_vars = set_order_liquid_vars
          @liquid_vars = @liquid_vars.merge(set_invoice_liquid_vars)
          @mail_type = 'order'
          @mailer_path = 'order_mailer/approved_email'
        when 'cancel_email'
          @liquid_vars = set_order_liquid_vars
          @mail_type = 'order'
          @mailer_path = 'order_mailer/cancel_email'
        when 'final_invoice_email'
          @liquid_vars = set_order_liquid_vars
          @liquid_vars = @liquid_vars.merge(set_invoice_liquid_vars)
          @mail_type = 'order'
          @mailer_path = 'order_mailer/final_invoice_email'
        when 'review_order_email'
          @liquid_vars = set_order_liquid_vars
          @liquid_vars = @liquid_vars.merge(set_invoice_liquid_vars)
          @mail_type = 'order'
          @mailer_path = 'order_mailer/review_order_email'
        when 'unapprove'
          @liquid_vars = set_order_liquid_vars
          @mail_type = 'order'
          @mailer_path = 'order_mailer/unapprove'
        when 'shipped_email'
          @liquid_vars = set_shipment_liquid_vars # set up liquid vars
          @liquid_vars = @liquid_vars.merge(set_order_liquid_vars)
          @liquid_vars = @liquid_vars.merge(set_invoice_liquid_vars)
          @mail_type = 'shipped'
          @mailer_path = 'shipment_mailer/shipped_email'
        when 'reminder_email'
          @liquid_vars = set_order_liquid_vars
          @liquid_vars = @liquid_vars.merge(set_invoice_liquid_vars)
          @mail_type = 'invoice'
          @mailer_path = 'invoice_mailer/reminder_email'
        when 'past_due_email'
          @liquid_vars = set_order_liquid_vars
          @liquid_vars = @liquid_vars.merge(set_invoice_liquid_vars)
          @invoice.end_date = Date.current - 3.weeks
          @invoice.due_date = Date.current - 1.week
          @mail_type = 'invoice'
          @mailer_path = 'invoice_mailer/past_due_email'
        when 'weekly_invoice_email'
          @liquid_vars = set_order_liquid_vars
          @liquid_vars = @liquid_vars.merge(set_invoice_liquid_vars)
          @mail_type = 'invoice'
          @mailer_path = 'invoice_mailer/weekly_invoice_email'
        else # just in case something doesn't match...
          @liquid_vars = set_order_liquid_vars
          @mail_type = 'invoice'
          @mailer_path = 'invoice_mailer/invoice_email'
        end

        # parse liquid vars into text in email body and subject
        @body = @email_template.render_preview(params[:body], @liquid_vars)
        @subject = params[:subject] ? Liquid::Template.parse(params[:subject]).render(@liquid_vars) : ""

      end

      def attach_pdf

      end

      private

      def email_template_params
        params.require(:email_template).permit([ :slug, :from, :cc, :bcc, :subject, :body, :attach_pdf ])
      end

      def setup_attach_pdf_vars
        case @email_template.slug
        when "approved_email"
          @attach_pdf_option_exists = true
          @attach_pdf = current_vendor.send_approved_email_invoice
        when "shipped_email"
          @attach_pdf_option_exists = true
          @attach_pdf = current_vendor.send_shipped_email_invoice
        when "final_invoice_email"
          @attach_pdf_option_exists = true
          @attach_pdf = current_vendor.send_final_invoice_email_invoice
        end
      end

    end
  end
end
