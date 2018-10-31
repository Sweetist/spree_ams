module Spree
  module Manage
    class ProductionsController < Spree::Manage::BaseController
     before_action :ensure_read_permission, only: [:show]
     before_action :clear_current_order

     def show
       @vendor = current_vendor
       @dates ||= {}

       @dates[:start] = date_field_with_defaults(:start_date, @vendor)
       @dates[:end] = date_field_with_defaults(:end_date, @vendor)
       params[:start_date] = @dates[:start]
       params[:end_date] = @dates[:end]
       params[:order_states] = ['complete', 'approved'] if params[:order_states].blank?

       @orders = current_vendor.sales_orders
         .includes(line_items: :variant)
         .where('spree_orders.delivery_date BETWEEN ? AND ?', @dates[:start], @dates[:end])
         .where('spree_orders.state IN (?)', params[:order_states])

       if params[:account_ids].present?
         @orders = @orders.where('spree_orders.account_id IN (?)', params[:account_ids])
       end

       @variants = Spree::Variant.production_list(
         @vendor,
         params[:start_date],
         params[:end_date],
         params[:order_states],
         params[:account_ids]
       )

       revert_date_to_view_format(nil, :start_date, @vendor)
       revert_date_to_view_format(nil, :end_date, @vendor)

       render :show
     end

     def by_customer
        @vendor = current_vendor
        @dates ||= {}
        @dates[:start] = date_field_with_defaults(:start_date, @vendor)
        @dates[:end] = date_field_with_defaults(:end_date, @vendor)
        params[:start_date] = @dates[:start]
        params[:end_date] = @dates[:end]

        @account_ids = params[:account_ids]
        params[:order_states] = ['complete', 'approved'] if params[:order_states].blank?

        @report = Production::ByCustomerReport.new(vendor: @vendor,
                                                   account_ids: params[:account_ids],
                                                   order_states: params[:order_states],
                                                   date_start: @dates[:start],
                                                   date_end: @dates[:end])

       revert_date_to_view_format(nil, :start_date, @vendor)
       revert_date_to_view_format(nil, :end_date, @vendor)

     end

     def download_xlsx
       @dates ||= {}
       @vendor = current_company
       params[:order_states] = ['complete', 'approved'] if params[:order_states].blank?

       send_data(
         Spree::Variant.to_production_report_xlsx({
           vendor: @vendor,
           start_date: params[:start_date],
           end_date: params[:end_date],
           order_states: params[:order_states],
           account_ids: params[:account_ids]
         }).to_stream.read,
         filename: "production_report_#{params[:start_date].to_date.strftime('%Y-%m-%d')}_#{params[:end_date].to_date.strftime('%Y-%m-%d')}.xlsx",
         type: 'application/xlsx'
       )

     end


     private

     def ensure_read_permission
       unless current_spree_user.can_read?('production_reports', 'reports')
         flash[:error] = 'You do not have permission to view production reports'
         redirect_to manage_path
       end
     end

    end
  end
end
