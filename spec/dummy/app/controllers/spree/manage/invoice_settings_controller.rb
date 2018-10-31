module Spree
  module Manage
    class InvoiceSettingsController < Spree::Manage::BaseController

      before_action :ensure_write_permission

      def show
        redirect_to edit_manage_invoice_settings_path
      end

      def edit
        @account = spree_current_user.company
        session[:vendor_id] = @account.id
        render :edit
      end

      def update
        @account = spree_current_user.company
        session[:vendor_id] = @account.id
        if @account.update(account_params)
          #flash[:success] = "Your invoice settings updated"
          if params[:update_carts] == 'true'
            @account.update_cart_numbers
          end
          flash[:success] = Spree.t(:successfully_updated, resource: Spree.t(:settings, scope: :print_invoice))
          redirect_to edit_manage_invoice_settings_path
          #render :edit
        else
          flash[:errors] = @account.errors.full_messages
          redirect_to edit_manage_invoice_settings_path
          #render :edit
        end
      end

      protected

        def account_params
          params.require(:company).permit(
            :po_order_prefix,
            :po_order_next_number,
            :next_number,
            :invoice_prefix,
            :use_separate_invoices,
            :multi_order_invoice,
            :send_invoices,
            :order_next_number,
            :order_prefix,
            :use_po_number,
            :resubmit_orders,
            :last_editable_order_state,
            :receive_orders,
            :auto_approve_orders,
            :txn_class_type,
            :order_date_text,
            :logo_path,
            :page_size,
            :page_layout,
            :footer_left,
            :footer_right,
            :return_message,
            :anomaly_message,
            :use_footer,
            :use_page_numbers,
            :logo_scale,
            :font_face,
            :font_size,
            :store_pdf,
            :storage_path,
            :include_total_weight,
            :include_unit_weight,
            :po_include_total_weight,
            :po_include_unit_weight,
            :invoice_pdf_include_unit_weight,
            :invoice_pdf_include_total_weight,
            :invoice_pdf_include_balance,
            :po_pdf_include_unit_weight,
            :po_pdf_include_total_weight,
            :weight_units,
            :po_footer_left,
            :po_footer_right,
            :po_pdf_price,
            :hard_cutoff_time,
            :hard_lead_time,
            :bol_terms_and_condtions1,
            :bol_terms_and_condtions2,
            :bol_terms_and_condtions3,
            :bol_require_shipper_signature,
            :bol_require_receiver_signature
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
