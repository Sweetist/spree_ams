module Spree
  module Manage
    class RootController < Spree::Manage::BaseController


      #skip_before_filter :authorize_admin
      before_action :clear_current_order

      def index
        # temporarily forwarding to products#index as landing page
        redirect_to manage_root_redirect_path
      end

      def overview
        @company = current_company

        overview_date = DateHelper.company_date_to_UTC(params.fetch("overview-date", DateHelper.to_vendor_date_format(Time.now.in_time_zone(current_vendor.time_zone), current_vendor.date_format)), current_vendor.date_format)
        end_date = Time.current
        start_date = end_date - 30.days

        if current_spree_user.can_read?('basic_options', 'reports')
          sales_dashboard(overview_date, start_date, end_date)
        else
          operations_dashboard(overview_date, start_date, end_date)
        end
      end

      def operations_dashboard(overview_date, start_date, end_date)
        sql_arr = [
          Spree::Product.products_query({
            delivery_date_gteq: true,
            delivery_date_lteq: true
          }),
          @company.id, ApprovedStates, start_date, end_date
        ]
        @quantity = Hash.new(0)
        @line_items = Spree::LineItem.find_by_sql(sql_arr)
        @line_items.each do |li_group|
          @quantity[li_group.default_display_name] = li_group.quantity
        end

        product_show_count = 5

        @product_sales_bar_chart_data = ReportHelper.build_bar_chart(
          ReportHelper.sorted_data(@quantity, product_show_count),
          "Quantity Sold",
          'Product Sales, Last 30 Days',
          "Quantity Sold"
        )
        @product_sales_pie_chart_data = ReportHelper.build_pie_chart(
          ReportHelper.sorted_data(@quantity, product_show_count),
          "Quantity Sold",
          'Product Sales, Last 30 Days'
        )

        @daily_purchase_orders = @company.purchase_orders
                                         .invoiceable
                                         .includes(account: :vendor)
                                         .where('invoice_date = ?', overview_date)
                                         .order('completed_at ASC')

      end

      def sales_dashboard(overview_date, start_date, end_date)
        @customer_account_sales = Hash.new(0)
        totals = Hash.new(0)
        @customers = @company.customers
        @orders = @company.sales_orders.includes(:account)
                 .approved
                 .where('delivery_date BETWEEN ? AND ?', start_date, overview_date).order('delivery_date ASC')

        @orders.each do |order|
          @customer_account_sales[order.account.fully_qualified_name] += order.total
          totals[order.delivery_date] += order.total
        end

        order_totals_data = []
        totals.sort_by {|date, total| date}.each do |date, total|
          order_totals_data << [date.to_i*1000, total.to_i]
        end

        @daily_orders = @company.sales_orders.approved.includes(:account)
                        .where('delivery_date = ?', overview_date)

        @sales_history_chart_data = ReportHelper.build_areaspline_chart(order_totals_data, '30 Day Sales',"Total Sales (#{@company.currency})" )
        @customer_account_sales_bar_chart_data = ReportHelper.build_bar_chart(
          ReportHelper.sorted_data(@customer_account_sales, 5), # 5 is number of accounts we count individually
          "Sales (#{CurrencyHelper.currency_symbol(@company.currency)})",
          'Sales by Account, Last 30 Days',
          "Sales (#{@company.currency})"
        )
        @customer_account_sales_pie_chart_data = ReportHelper.build_pie_chart(
          ReportHelper.sorted_data(@customer_account_sales, 5), # 5 is number of accounts we count individually
          "Sales (#{CurrencyHelper.currency_symbol(@company.currency)})",
          'Sales by Account, Last 30 Days'
        )

        @any_orders_today = @company.sales_orders.where(state: InvoiceableStates, delivery_date: overview_date).exists?
        @any_approved_orders_today = @daily_orders.present?
      end

      protected

      def manage_root_redirect_path
        spree.manage_overview_path
      end
    end
  end
end
