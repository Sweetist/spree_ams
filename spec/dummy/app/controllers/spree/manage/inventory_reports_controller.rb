module Spree
  module Manage
    class InventoryReportsController < Spree::Manage::BaseController
      before_action :ensure_read_permission
      before_action :load_shared_variables
      around_filter :query_cache_second_base

      def detail_report
        @report_data = InventoryHistory::DetailReport.new(company_id: @vendor.id,
                                                          date_start: @dates[:start],
                                                          date_end: @dates[:end],
                                                          stock_location_ids: stock_location_ids,
                                                          page: params[:page])

        revert_date_to_view_format(nil, :start_date, @vendor)
        revert_date_to_view_format(nil, :end_date, @vendor)

        render :detail_report
      end

      def summary_report
        @report_data = InventoryHistory::SummaryReport.new(company_id: @vendor.id,
                                                           date_start: @dates[:start],
                                                           date_end: @dates[:end],
                                                           stock_location_ids: stock_location_ids)

        revert_date_to_view_format(nil, :start_date, @vendor)
        revert_date_to_view_format(nil, :end_date, @vendor)

        render :summary_report
      end

      def download_csv
        report_data = InventoryHistory::DetailReport.new(company_id: @vendor.id,
                                                          date_start: @dates[:start],
                                                          date_end: @dates[:end],
                                                          stock_location_ids: stock_location_ids,
                                                          export: true)
        update_headers(@vendor)
        self.response_body = Enumerator.new do |yielder|
          yielder << line_head(@vendor).to_csv
          report_data.items.each do |item|
            yielder << [item.title].to_csv
            yielder << beginning_balance_line(item).to_csv
            item.lines.each do |item_line|
              yielder << item_line.line_for_export(@vendor,
                                                   @stock_location_ids).to_csv
            end
            yielder << item_total_line(item).to_csv
            yielder << ['', '', '', '', ''].to_csv
          end
        end

        response.status = 200
      end

      private

      def update_headers(vendor)
        headers.delete('Content-Length')
        headers['Cache-Control'] = 'no-cache'
        headers['Content-Type'] = 'text/csv'
        headers['Content-Disposition'] = "attachment; filename=\"#{Time.current.in_time_zone(vendor.try(:time_zone)).strftime('%Y-%m-%d')}_inventory.csv\""
        headers['X-Accel-Buffering'] = 'no'
      end

      def line_head(vendor)
        line_head = ['Date', 'Transaction Type', 'Number', 'Customer / Reason',
          'Customer Type']
        @stock_location_ids.each do |stock_id|
          line_head += ["#{@vendor.stock_locations.find(stock_id).name.titleize} Quantity",
            "#{@vendor.stock_locations.find(stock_id).name.titleize} QOH"]
        end
        line_head += ['Quantity Total', 'QOH Total']
      end

      def beginning_balance_line(item)
        line_base = ['Beginning Balance', '', '', '', '']
        @stock_location_ids.each do |stock_id|
          line_base += ['', item.start_balance_for_stock_location(stock_id)]
        end
        line_base += ['', item.start_total_qty_on_hand]
      end

      def item_total_line(item)
        line_base = ["Total for #{item.title}", '', '', '', '']
        @stock_location_ids.each do |stock_id|
          line_base += ['', item.end_balance_for_stock_location(stock_id)]
        end
        line_base += ['', item.end_total_qty_on_hand]
      end

      def query_cache_second_base
        SecondBase::Base.connection.cache { yield }
      end

      def load_shared_variables
        @vendor = current_vendor
        @dates ||= {}
        @dates[:start] = date_field_with_defaults(:start_date, @vendor, 3.months)
        @dates[:end] = date_field_with_defaults(:end_date, @vendor)
        params[:start_date] = @dates[:start]
        params[:end_date] = @dates[:end]
        @stock_location_ids = stock_location_ids
      end

      def stock_location_ids
        return params[:stock_locations].map(&:to_i) if params[:stock_locations]

        @vendor.stock_locations.active.pluck(:id)
      end

      def ensure_read_permission
        return if current_spree_user.can_read?('basic_options', 'reports')

        flash[:error] = 'You do not have permission to view sales reports'
        redirect_to manage_path
      end
    end
  end
end
