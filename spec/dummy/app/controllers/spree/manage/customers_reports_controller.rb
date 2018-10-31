module Spree
  module Manage
    class CustomersReportsController < Spree::Manage::BaseController

      before_action :clear_current_order
      before_action :ensure_read_permission, only: [:show]

      def show
        @vendor = current_vendor
        @dates = {}
        params[:q] ||= {}

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

        @account_show_count = params[:account_show_count] || 30 #30 is just a number we decided on to show, no special value
        @content_options = [{name: 'Spend', slug: 'spend'}, {name: 'Items', slug: 'items'}, {name: 'Orders', slug: 'orders'}]
        if params[:account_ids].blank?
          if params[:sub_accounts] || cookies['sub_accounts'] == 'true'
            customers_names = @vendor.customer_accounts.where(parent_id: nil).pluck(:customer_id, :name).to_h
            orders = @vendor.sales_orders.joins(account: :customer)
              .select("sum(total) as spend, sum(item_count) as items_purchased, spree_orders.count as num_orders,
              count(delivery_date) as num_orders, spree_accounts.customer_id, currency")
              .where('spree_orders.state IN (?)', params[:order_states])
              .ransack(params[:q]).result.group('spree_accounts.customer_id', :currency)

            @orders = {}
            orders.each do |order|
              @orders[customers_names[order.customer_id]] = order
            end
          else
            @orders = @vendor.sales_orders
              .includes(:account)
              .select("sum(total) as spend, sum(item_count) as items_purchased, spree_orders.count as num_orders,
              count(delivery_date) as num_orders, account_id, currency")
              .where('spree_orders.state IN (?)', params[:order_states])
              .ransack(params[:q]).result.group(:account_id, :currency)
          end
        else
          if params[:sub_accounts] || cookies['sub_accounts'] == 'true'
            customers_names = @vendor.customer_accounts.where(parent_id: nil).pluck(:customer_id, :name).to_h
            orders = @vendor.sales_orders.joins(account: :customer)
              .select("sum(total) as spend, sum(item_count) as items_purchased, spree_orders.count as num_orders,
              count(delivery_date) as num_orders, spree_accounts.customer_id, currency")
              .where('spree_orders.account_id IN (?) OR spree_accounts.parent_id IN (?)', params[:account_ids], params[:account_ids])
              .where('spree_orders.state IN (?)', params[:order_states])
              .ransack(params[:q]).result.group('spree_accounts.customer_id', :currency)

            @orders = {}
            orders.each do |order|
              @orders[customers_names[order.customer_id]] = order
            end
          else
            @orders = @vendor.sales_orders
              .includes(:account)
              .select("sum(total) as spend, sum(item_count) as items_purchased, spree_orders.count as num_orders,
              count(delivery_date) as num_orders, account_id, currency")
              .where('spree_orders.account_id IN (?)', params[:account_ids])
              .where('spree_orders.state IN (?)', params[:order_states])
              .ransack(params[:q]).result.group(:account_id, :currency)
          end
        end

        build_charts(@orders, @account_show_count)

        @dates[:start] = params[:q][:delivery_date_gteq].try(:to_date).to_s
        @dates[:start] = params[:q][:completed_at_gteq].try(:to_date).to_s if @dates[:start].blank?
        @dates[:start] = params[:q][:approved_at_gteq].try(:to_date).to_s if @dates[:start].blank?
        @dates[:end] = params[:q][:delivery_date_lteq].try(:to_date).to_s
        @dates[:end] = params[:q][:completed_at_lteq].try(:to_date).to_s if @dates[:end].blank?
        @dates[:end] = params[:q][:approved_at_lteq].try(:to_date).to_s if @dates[:end].blank?

        revert_ransack_date_to_view(:delivery_date_gteq, @vendor)
        revert_ransack_date_to_view(:delivery_date_lteq, @vendor)
        revert_ransack_datetime_to_view(:completed_at_gteq, @vendor)
        revert_ransack_datetime_to_view(:completed_at_lteq, @vendor)
        revert_ransack_datetime_to_view(:approved_at_gteq, @vendor)
        revert_ransack_datetime_to_view(:approved_at_lteq, @vendor)

        render :show
      end

      def build_charts(orders, account_show_count)
        @total_spend, @total_items, @total_orders = 0,0,0
        spend = Hash.new(0)
        items = Hash.new(0)
        num_orders = Hash.new(0)
        if orders.class == Hash
          orders.each do |name, order|
            spend[name] += order.spend
            @total_spend += order.spend
            items[name] += order.items_purchased
            @total_items += order.items_purchased
            num_orders[name] += order.num_orders
            @total_orders += order.num_orders
          end
        else
          orders.each do |order|
            spend[order.account.fully_qualified_name] = order.spend
            @total_spend += order.spend
            items[order.account.fully_qualified_name] = order.items_purchased
            @total_items += order.items_purchased
            num_orders[order.account.fully_qualified_name] = order.num_orders
            @total_orders += order.num_orders
          end
        end

        @currency = CurrencyHelper.currency_symbol(current_vendor.currency)
        @spend_chart_data = ReportHelper.build_bar_chart(ReportHelper.sorted_data(spend, account_show_count), "Spend (#{@currency})", "Sales By Account", "Total Sales (#{@currency})")
        @items_chart_data = ReportHelper.build_bar_chart(ReportHelper.sorted_data(items, account_show_count), "Items", "Items Purchased By Account", "Total Number of Items Purchased")
        @orders_chart_data = ReportHelper.build_bar_chart(ReportHelper.sorted_data(num_orders, account_show_count), "Orders", "Orders By Account", "Total Number of Orders Completed")
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
