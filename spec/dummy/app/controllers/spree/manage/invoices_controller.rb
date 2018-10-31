module Spree
  module Manage
    class InvoicesController < Spree::Manage::BaseController

      helper_method :sort_column, :sort_direction
      before_action :clear_current_order, only: [:index, :show]
      before_action :set_current_invoice, only: [:show, :edit, :update]
      before_action :ensure_vendor, only: [:show, :edit, :update, :void, :mark_paid]
      before_action :ensure_edit_permission, only: [:update]
      before_action :ensure_view_permission, only: [:index, :show, :daily]
      before_action :ensure_payment_permission, only: [:mark_paid]
      respond_to :js

      def index
        params[:q] ||= {}
        # params[:q][:payment_state_matches_any] = Spree::Invoice::PaymentStates if params[:q][:payment_state_matches_any].blank?
        # params[:q][:payment_state_matches_any] += [nil, '']
        @vendor = current_vendor
        format_ransack_date_field(:end_date_gteq, @vendor)
        format_ransack_date_field(:end_date_lteq, @vendor)
        format_ransack_date_field(:due_date_gteq, @vendor)
        format_ransack_date_field(:due_date_lteq, @vendor)

        @any_invoices_today = @vendor.sales_invoices.where(end_date: overview_date_t).exists?
        @search = @vendor.sales_invoices.order('end_date DESC').ransack(params[:q])
        @invoices = @search.result.includes(account: :customer).page(params[:page])

        # This part is needed to supply correct params to pagination
        revert_ransack_date_to_view(:end_date_gteq, @vendor)
        revert_ransack_date_to_view(:end_date_lteq, @vendor)
        revert_ransack_date_to_view(:due_date_gteq, @vendor)
        revert_ransack_date_to_view(:due_date_lteq, @vendor)

        render :index
      end

      def show
        @bookkeeping_document = @invoice.pdf_invoice

        respond_with(@bookkeeping_document) do |format|
          format.pdf do
            send_data @bookkeeping_document.pdf, type: 'application/pdf', disposition: 'inline'
          end
          format.html {redirect_to edit_manage_invoice_path(@invoice)}
        end
      end

      def edit
        if @invoice.multi_order
          @line_items = @invoice.grouped_line_items
        else
          @search = @invoice.line_items.ransack(params[:q])
          @search.sorts = @vendor.cva.try(:line_item_default_sort) if @search.sorts.empty?
          @line_items = @search.result.includes(line_item_lots: :lot)
          @line_items ||= []
        end

        respond_with(@bookkeeping_document) do |format|
          format.pdf {redirect_to manage_invoice_path(@invoice)}
          format.html {render :edit}
        end
      end

      def update
        if params[:invoice][:due_date].blank?
          params[:invoice][:due_date] = @invoice.due_date
        else
          format_form_date_field(:invoice, :due_date, @vendor)
        end
        if params[:invoice][:invoice_date].blank?
          params[:invoice][:invoice_date] = @invoice.invoice_date
        else
          format_form_date_field(:invoice, :invoice_date, @vendor)
        end
        if @invoice.update(invoice_params)
          if @invoice.multi_order
            @invoice.orders.update_all(due_date: params[:invoice][:due_date])
          else
            @invoice.orders.update_all(due_date: params[:invoice][:due_date], invoice_date: params[:invoice][:invoice_date])
          end
          flash[:success] = 'Your invoice has been successfully updated!'
          handle_success_render(edit_manage_invoice_path(@invoice))
        else
          flash[:error] = 'Your invoice has not been updated!'
        end
      end

      def actions_router
        if [Spree.t('payment_actions.mark.paid'), Spree.t('payment_actions.mark.unpaid')].include?(params[:commit])
          unless current_spree_user.can_write?('payments', 'order')
            flash[:error] = 'You do not have permission to edit payments'
            redirect_to manage_invoices_path and return
          end
        end

        @vendor = current_vendor
        if params[:company] && params[:company][:sales_invoices_attributes]
          params[:company][:sales_invoices_attributes] ||= {}
          invoice_ids = params[:company][:sales_invoices_attributes].map {|k, v| v[:id] if v[:action] == '1'}.compact
        end

        sort = params[:sort]
        case params[:commit]
        when 'Collate Selected Invoices'
          redirect_to collate_invoices_manage_invoices_path(invoice_ids: invoice_ids, sort: sort) and return
        when Spree.t(:send_invoice)
          @vendor.sales_invoices.where(id: invoice_ids).each(&:send_invoice)
          flash[:success] = "Emails will be sent shortly"
        when Spree.t(:send_invoice_reminder)
          @vendor.sales_invoices.where(id: invoice_ids).each(&:send_reminder)
          flash[:success] = "Emails will be sent shortly"
        when Spree.t('payment_actions.mark.paid')
          mark_invoices_paid(@vendor, invoice_ids)
        end

        redirect_to manage_invoices_url
      end

      def collate_invoices(invoice_ids = nil, sort = 'spree_accounts.fully_qualified_name')
        sort = params[:sort] if params[:sort].present?
        if sort.start_with?('delivery_date')
          sort = "end_date #{sort.split(' ').last}"
        end
        invoice_ids ||= params[:invoice_ids]
        vendor = current_vendor
        invoices = vendor.sales_invoices.includes(:account).where(id: invoice_ids).order(sort)

        if invoices.present?
          bookkeeping_document = CombinePDF.new
          invoices.each {|invoice| bookkeeping_document << CombinePDF.parse(invoice.pdf_invoice.pdf)}
          send_data bookkeeping_document.to_pdf, filename: "#{Time.current.in_time_zone(vendor.try(:time_zone)).strftime('%Y-%m-%d')}_invoices.pdf", type: 'application/pdf', disposition: 'inline'
        else
          flash[:error] = "No invoices were selected"
          redirect_to manage_invoices_url
        end
      end

      def daily(date = nil, sort = 'spree_accounts.fully_qualified_name asc')
        @vendor = current_vendor

        sort = params[:sort] if params[:sort].present?
        if sort.start_with?('delivery_date')
          sort = "end_date #{sort.split(' ').last}"
        end

        date ||= overview_date_t
        @daily_invoices = @vendor.sales_invoices.where('end_date = ?', date)
        @daily_orders = @vendor.sales_orders.approved.includes(:customer, :line_items).where('delivery_date = ?', date).order(sort)

        @bookkeeping_document = CombinePDF.new
        if @daily_invoices.present?
          @daily_invoices.each {|invoice| @bookkeeping_document << CombinePDF.parse(invoice.pdf_invoice.pdf)}

          respond_with(@bookkeeping_document) do |format|
            format.pdf do
              send_data @bookkeeping_document.to_pdf, filename: "#{date.strftime('%Y-%m-%d')}_daily_invoices.pdf", type: 'application/pdf', disposition: 'inline'
            end
          end
        else
          flash[:error] = "There are no orders with a date of #{overview_date}"
          redirect_to :back
        end
      end

      def separate_invoice
        @order = current_vendor.sales_orders.friendly.find(params[:id])
        @order.update_invoice(true) #passing force_individual = true
        flash[:success] = "Invoice updated."
        redirect_to :back
      end

      def send_invoice
        @invoice = current_vendor.sales_invoices.find(params[:id]) rescue nil
        flash[:success] = 'Email wil be sent shortly'
        # takes (invoice_id, override_account_email_settings)
        @invoice.send_invoice
      end

      def send_reminder
        @invoice = current_vendor.sales_invoices.find(params[:id]) rescue nil
        flash[:success] = 'Email wil be sent shortly'
        # takes (invoice_id, override_account_email_settings)
        @invoice.send_reminder
      end

      def void
        unless current_spree_user.can_write?('invoice')
          flash[:error] = 'You do not have permission to void transactions'
          redirect_to :back and return
        end

        if @invoice.void(current_spree_user.try(:id))
          flash[:success] = "Invoice #{@invoice.number} has been voided."
          redirect_to manage_invoices_path
        else
          flash[:errors] = @invoice.errors.full_messages
          redirect_to :back
        end
      end

      def payment_states
        @invoices = current_vendor.sales_invoices.where('updated_at > ?', Time.current - 10.seconds)
        if @invoices.present?
          render :update_payment_states
        else
          head 200
        end
      end

      def mark_paid
        respond_with(@invoice) do |format|
          format.js do
            if @invoice.mark_paid
              flash[:success] = "Invoice #{@invoice.reload.payment_state}."
            else
              flash[:errors] = @invoice.errors.full_messages
            end
            render :update_payment_state
          end
        end
      end

      def mark_invoices_paid(vendor, invoice_ids)
        unless vendor.can_mark_paid?
          flash[:error] = 'You must select a payment method to use to mark invoices paid.'
          return
        end
        invoices = vendor.sales_invoices.where(id: invoice_ids).where.not(payment_state: 'paid')
        if invoices.empty?
          flash[:error] = 'You must select unpaid invoices to mark paid.'
          return
        end

        flash[:success] = "Updating payment status on #{invoices.count} #{'invoice'.pluralize(invoices.count)}."
        invoices.update_all(payment_state: 'updating')
        vendor.sales_orders.where(invoice_id: invoice_ids)
                           .where.not(payment_state: 'paid')
                           .update_all(payment_state: 'updating')

        Sidekiq::Client.push(
          'class' => MarkPaid,
          'queue' => 'critical',
          'args' => [vendor.id, 'Spree::Invoice', invoice_ids]
        )
      end

      private

      def ensure_vendor
        @invoice= Spree::Invoice.find_by_id(params[:id])
        unless current_vendor.id == @invoice.try(:vendor_id)
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to root_url
        end
      end

      def ensure_view_permission
        unless current_spree_user.can_read?('invoice')
          flash[:error] = 'You do not have permission to view invoices'
          redirect_to manage_path
        end
      end

      def ensure_edit_permission
        unless current_spree_user.can_write?('invoice')
          flash[:error] = 'You do not have permission to edit invoices'
          redirect_to manage_path
        end
      end

      def ensure_payment_permission
        unless current_spree_user.can_write?('payments', 'order')
          flash[:error] = 'You do not have permission to edit payments'
          redirect_to manage_invoices_path
        end
      end

      def invoice_params
        params.require(:invoice).permit(:invoice_date, :due_date)
      end

      def handle_success_render(redirect_path)
        respond_with(@invoice) do |format|
          format.js do
            render js: "window.location.href = '" + redirect_path + "'"
          end
          format.html do
            redirect_to redirect_path
          end
        end
      end

      def set_current_invoice
        @vendor = current_vendor
        @invoice = @vendor.sales_invoices.includes(account: [:shipping_addresses, :billing_addresses]).find(params[:id])
      end
    end
  end
end
