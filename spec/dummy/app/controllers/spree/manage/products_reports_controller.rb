module Spree
  module Manage
    class ProductsReportsController < Spree::Manage::BaseController

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

        @product_show_count = params[:product_show_count] ? params[:product_show_count].to_i : 20 #20 is just a number we decided on to show, no special value
        @content_options = [{name: 'Revenue', slug: 'revenue'}, {name: 'Unique Purchases', slug: 'unique-purchases'}, {name: 'Quantity', slug: 'quantity'}]

        sql_query = Spree::Product.products_query({
            delivery_date_gteq: params[:q][:delivery_date_gteq].present?,
            delivery_date_lteq: params[:q][:delivery_date_lteq].present?,
            completed_at_gteq: params[:q][:completed_at_gteq].present?,
            completed_at_lteq: params[:q][:completed_at_lteq].present?,
            approved_at_gteq: params[:q][:approved_at_gteq].present?,
            approved_at_lteq: params[:q][:approved_at_lteq].present?,
            account_id: params[:account_ids].present?,
            variant_id: params[:variant_ids].present?
          })

        sql_arr = [sql_query, @vendor.id, params[:order_states]]

        sql_arr << params[:q][:delivery_date_gteq] if params[:q][:delivery_date_gteq].present?
        sql_arr << params[:q][:delivery_date_lteq] if params[:q][:delivery_date_lteq].present?
        sql_arr << params[:q][:completed_at_gteq] if params[:q][:completed_at_gteq].present?
        sql_arr << params[:q][:completed_at_lteq] if params[:q][:completed_at_lteq].present?
        sql_arr << params[:q][:approved_at_gteq] if params[:q][:approved_at_gteq].present?
        sql_arr << params[:q][:approved_at_lteq] if params[:q][:approved_at_lteq].present?
        sql_arr << params[:account_ids] if params[:account_ids].present?
        sql_arr << params[:variant_ids] if params[:variant_ids].present?

        @line_items = Spree::LineItem.find_by_sql(sql_arr)
        @total_revenue, @total_uniq_purchases, @total_quantity = 0,0,0
        @revenue = Hash.new(0)
        @uniq_purchases = Hash.new(0)
        @quantity = Hash.new(0)
        @line_items.each do |li_group|
          @revenue[li_group.default_display_name] = li_group.revenue
          @total_revenue += li_group.revenue
          @uniq_purchases[li_group.default_display_name] = li_group.uniq_purchases
          @total_uniq_purchases += li_group.uniq_purchases
          @quantity[li_group.default_display_name] = li_group.quantity
          @total_quantity += li_group.quantity
        end

        build_charts(@revenue, @uniq_purchases, @quantity, @product_show_count)

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

      def build_charts(revenue, uniq_purchases, quantity, product_show_count)
        @currency = CurrencyHelper.currency_symbol(current_vendor.currency)
        @revenue_chart_data = ReportHelper.build_bar_chart(ReportHelper.sorted_data(revenue, product_show_count), "Sales (#{@currency})", "Product Revenue", "Total Sales (#{@currency})")
        @uniq_purchases_chart_data = ReportHelper.build_bar_chart(ReportHelper.sorted_data(uniq_purchases, product_show_count), "Qty", "Unique Purchases", "Number of Unique Purchases")
        @quantity_chart_data = ReportHelper.build_bar_chart(ReportHelper.sorted_data(quantity, product_show_count), "Qty", "Total Ordered", "Total Number of Items Ordered")
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
