module Spree
  module Manage
    class TotalSalesReportsController < Spree::Manage::BaseController

      before_action :ensure_read_permission, only: [:show]
      before_action :clear_current_order
      def show
        @vendor = current_vendor
        params[:q] ||= {}
        @dates = {}

        if params[:q][:delivery_date_gteq].nil?
          params[:q][:delivery_date_gteq] = (Time.current - 3.months).in_time_zone(@vendor.time_zone).to_date
          params[:q][:delivery_date_lteq] = Time.current.in_time_zone(@vendor.time_zone).to_date
        else
          format_ransack_date_field(:delivery_date_gteq, @vendor)
          format_ransack_date_field(:delivery_date_lteq, @vendor)
        end
        format_ransack_datetime_field(:completed_at_gteq, @vendor)
        format_ransack_datetime_field(:completed_at_lteq, @vendor)
        format_ransack_datetime_field(:approved_at_gteq, @vendor)
        format_ransack_datetime_field(:approved_at_lteq, @vendor)

        params[:order_states] = ApprovedStates.dup if params[:order_states].blank?

        @content_options = [{name: 'Revenue', slug: 'revenue'}, {name: 'Items', slug: 'items'}, {name: 'Orders', slug: 'orders'}]

        params[:q] ||= {}
        @orders = @vendor.sales_orders
                         .where('state IN (?)', params[:order_states])

        @search = @orders.ransack(params[:q])
        @orders = @search.result.includes(:account).order('delivery_date ASC')#.page(params[:page])
        build_charts(@orders)
        @dates[:start] = @orders.first.try(:delivery_date).try(:to_date).to_s
        @dates[:end] = @orders.last.try(:delivery_date).try(:to_date).to_s

        revert_ransack_date_to_view(:delivery_date_gteq, @vendor)
        revert_ransack_date_to_view(:delivery_date_lteq, @vendor)
        revert_ransack_datetime_to_view(:completed_at_gteq, @vendor)
        revert_ransack_datetime_to_view(:completed_at_lteq, @vendor)
        revert_ransack_datetime_to_view(:approved_at_gteq, @vendor)
        revert_ransack_datetime_to_view(:approved_at_lteq, @vendor)

        render :show
      end

      def build_charts(orders)
        @total_revenue, @total_items, @total_orders = 0,0,0
        revenue = Hash.new(0)
        items = Hash.new(0)
        num_orders = Hash.new(0)
        orders.each do |order|
          date = order.delivery_date.to_i * 1000
          revenue[date] += order.total
          @total_revenue += order.total
          items[date] += order.item_count
          @total_items += order.item_count
          num_orders[date] += 1
          @total_orders += 1
        end

        revenue_data, items_data, orders_data = [], [], []
        revenue.sort_by {|date, total| date}.each do |date, total|
          revenue_data << [date, total.to_i] #highcharts doesn't support decimals well
        end
        items.sort_by {|date, total| date}.each do |date, total|
          items_data << [date, total.to_i] #highcharts doesn't support decimals well
        end
        num_orders.sort_by {|date, total| date}.each do |date, total|
          orders_data << [date, total]
        end
        @revenue_chart_data = ReportHelper.build_areaspline_chart(revenue_data, "Sales Over Time", "Total Sales (#{CurrencyHelper.currency_symbol(current_vendor.currency)})")
        @items_chart_data = ReportHelper.build_areaspline_chart(items_data, "Products Sold Over Time", "Total Number of Items Purchased")
        @orders_chart_data = ReportHelper.build_areaspline_chart(orders_data, "Orders Over Time", "Total Number of Orders Completed")
      end

      private

      def ensure_read_permission
        unless current_spree_user.can_read?('basic_options', 'reports')
          flash[:error] = 'You do not have permission to view sales reports'
          redirect_to manage_path
        end
      end

    end
  end
end
