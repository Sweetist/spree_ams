module Spree
  module Manage
    class PackingListsController < Spree::Manage::BaseController
      before_action :ensure_read_permission, only: [:show]
      before_action :clear_current_order

      def show
        @vendor = current_vendor
        @dates ||= {}
        @dates[:start] = date_field_with_defaults(:start_date, @vendor)
        @dates[:end] = date_field_with_defaults(:end_date, @vendor)
        params[:start_date] = @dates[:start]
        params[:end_date] = @dates[:end]

        params[:q] ||= {}
        params[:q][:s] ||= 'number'

        params[:order_states] = ['complete', 'approved'] if params[:order_states].blank?
        @all_orders = current_vendor.sales_orders
                               .includes(account: :shipping_addresses, shipments: :stock_location, line_items: [:variant, line_item_lots: :lot])
                               .where('delivery_date BETWEEN ? AND ? AND spree_orders.state IN (?)', @dates[:start], @dates[:end], params[:order_states])
        if params[:account_ids]
          @all_orders = @all_orders.where('spree_orders.account_id IN (?)', params[:account_ids])
        end
        @all_orders = @all_orders.ransack(params[:q]).result
        @orders = @all_orders.page(params[:page]).per(10)
        revert_date_to_view_format(nil, :start_date, @vendor)
        revert_date_to_view_format(nil, :end_date, @vendor)
        respond_to do |format|
          format.html
          format.pdf
        end
      end

      def download_xlsx
        @vendor = current_vendor
        @dates ||= {}
        @dates[:start] = date_field_with_defaults(:start_date, @vendor)
        @dates[:end] = date_field_with_defaults(:end_date, @vendor)
        params[:start_date] = @dates[:start]
        params[:end_date] = @dates[:end]

        params[:q] ||= {}
        params[:q][:s] ||= 'number'

        params[:order_states] = ['complete', 'approved'] if params[:order_states].blank?
        orders = current_vendor.sales_orders
                               .includes(account: :shipping_addresses, shipments: :stock_location, line_items: [:variant, line_item_lots: :lot])
                               .where('delivery_date BETWEEN ? AND ? AND spree_orders.state IN (?)', @dates[:start], @dates[:end], params[:order_states])
        if params[:account_ids]
          orders = orders.where('spree_orders.account_id IN (?)', params[:account_ids])
        end
        orders = orders.ransack(params[:q]).result
        send_data(
         orders.to_packing_list_report_xlsx({
         }).to_stream.read,
         filename: "packing_list_report_#{params[:start_date].strftime('%Y-%m-%d')}_To_#{params[:end_date].strftime('%Y-%m-%d')}.xlsx",
         type: 'application/xlsx'
       )
      end
      private

      def ensure_read_permission
        unless current_spree_user.can_read?('production_reports', 'reports')
         flash[:error] = 'You do not have permission to view packing lists reports'
         redirect_to manage_path
        end
      end
    end
  end
end
