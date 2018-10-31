module Spree
  module Manage
    class OutgoingCommunicationsController < Spree::Manage::BaseController
      respond_to :js
      before_action :ensure_write_permission

      def edit
        @account = spree_current_user.company

        # Set up email template instance variables for edit links
        @invite_email_template = current_vendor.email_templates.find_by_slug('invite_email')
        @confirm_email_template = current_vendor.email_templates.find_by_slug('confirm_email')
        @approved_email_template = current_vendor.email_templates.find_by_slug('approved_email')
        @shipped_email_template = current_vendor.email_templates.find_by_slug('shipped_email')
        @review_order_email_template = current_vendor.email_templates.find_by_slug('review_order_email')
        @cancel_email_template = current_vendor.email_templates.find_by_slug('cancel_email')
        @final_invoice_email_template = current_vendor.email_templates.find_by_slug('final_invoice_email')
        @weekly_invoice_email_template = current_vendor.email_templates.find_by_slug('weekly_invoice_email')
        @unapprove_template = current_vendor.email_templates.find_by_slug('unapprove')
        @reminder_email_template = current_vendor.email_templates.find_by_slug('reminder_email')
        @past_due_email_template = current_vendor.email_templates.find_by_slug('past_due_email')

        session[:company_id] = @account.id
        render :edit
      end

      def update
        @account = spree_current_user.company
        session[:company_id] = @account.id
        if @account.update(account_params)
          flash[:success] = "Communication Settings updated"
          redirect_to edit_manage_outgoing_communications_path
        else
          flash.now[:errors] = @account.errors.full_messages
          render :edit
        end
      end

      def update_mail_to_settings
        @account = spree_current_user.company
        if Spree::Account.valid_mail_to_setting?(params[:mail_to_setting])
          @account.customer_accounts.update_all(send_mail: params[:mail_to_setting])
          flash[:success] = 'Account mail to settings successfully updated'
        else
          flash.now[:errors] = ["You must provide a valid mail to setting"]
        end
      end

      private

      def account_params
        params.require(:company).permit(
          :send_confirm_email,
          :send_approved_email,
          :send_approved_email_b2b_and_standing_only,
          :send_approved_email_invoice,
          :send_review_order_email,
          :send_cancel_email,
          :send_shipped_email,
          :send_shipped_email_invoice,
          :send_final_invoice_email,
          :send_final_invoice_email_invoice,
          :send_unapprove_email,
          :send_so_create_email,
          :send_so_update_email,
          :send_so_create_error_email,
          :send_so_process_error_email,
          :send_shipping_reminder,
          :send_cc_to_my_company,
          :send_mail_to_my_company,
          :send_weekly_invoice_email,
          :include_website_url_in_emails,
          :send_invoice_reminder,
          :invoice_reminder_days,
          :send_invoice_past_due,
          :invoice_past_due_days
        )
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = 'You do not have permission to view company settings'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('company')
          flash[:error] = 'You do not have permission to edit company settings'
          redirect_to manage_path
        end
      end

    end
  end
end
