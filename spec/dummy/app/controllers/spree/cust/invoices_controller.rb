module Spree
  module Cust
    class InvoicesController < Spree::Cust::CustomerHomeController
      helper_method :sort_column, :sort_direction
      before_action :ensure_customer, only: :show
      before_action :clear_current_order, only: [:index, :show]


      def index
        @customer = current_customer
        @vendors = @customer.vendors.order('name ASC')
        @vendor = current_vendor || @vendors.first
        @current_vendor_id = @vendor.try(:id)
        params[:q] ||= {}
        params[:q][:vendor_id_eq] = @current_vendor_id unless request.host == ENV['DEFAULT_URL_HOST']

        params[:q] ||= {}
        if params.fetch(:q).fetch(:payment_state_matches_any, []).include?('paid')
          params[:q][:payment_state_matches_any] << 'pending'
        end

        format_ransack_date_field(:end_date_gteq, @customer)
        format_ransack_date_field(:end_date_lteq, @customer)
        format_ransack_date_field(:due_date_gteq, @customer)
        format_ransack_date_field(:due_date_lteq, @customer)

        @search = @customer.purchase_invoices.where(account_id: current_spree_user.account_ids).order('end_date DESC').ransack(params[:q])
        @invoices = @search.result.includes(:account, :vendor).page(params[:page])

        revert_ransack_date_to_view(:end_date_gteq, @customer)
        revert_ransack_date_to_view(:end_date_lteq, @customer)
        revert_ransack_date_to_view(:due_date_gteq, @customer)
        revert_ransack_date_to_view(:due_date_lteq, @customer)

        respond_with(:manage, @invoices)
      end

      def show
        @customer = current_customer
        @invoice = @customer.purchase_invoices.includes(account: [:vendor]).find(params[:id])
        session[:vendor_id] = @invoice.vendor_id
        @vendor = current_vendor

        if @invoice.multi_order
          @line_items = @invoice.grouped_line_items
        else
          @search = @invoice.line_items.ransack(params[:q])
          @search.sorts = @vendor.cva.try(:line_item_default_sort) if @search.sorts.empty?
          @line_items = @search.result
        end

        @bookkeeping_document = @invoice.pdf_invoice

        respond_with(@bookkeeping_document) do |format|
          format.pdf do
            send_data @bookkeeping_document.pdf, type: 'application/pdf', disposition: 'inline'
          end
          format.html {render :show}
        end
      end

      private
      def ensure_customer
        @invoice = Spree::Invoice.find_by_id(params[:id])
        unless current_spree_user.vendor_accounts.find_by_id(@invoice.try(:account_id)).present?
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to root_url
        end
      end

      def sort_column
        if params[:action] == 'index'
          if Spree::Order.column_names.include?(params[:sort])
            params[:sort]
          elsif params[:sort] == "spree_vendor.name"
            params[:sort]
          else
            "delivery_date"
          end
        elsif params[:action] == 'edit'
          if Spree::LineItem.column_names.include?(params[:sort]) || params[:sort] == 'name'
            params[:sort]
          else
            'updated_at'
          end
        end
      end

      def sort_direction
        %w[asc desc].include?(params[:direction]) ?  params[:direction] : "DESC"
      end

    end
  end
end
