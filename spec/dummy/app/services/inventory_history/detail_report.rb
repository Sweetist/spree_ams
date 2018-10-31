module InventoryHistory
  # Creating detail report class
  class DetailReport
    attr_reader :items, :grand_total_qty, :grand_total_qty_on_hand,
                :stock_location_names, :total_pages, :current_page,
                :prev_page, :next_page, :limit_value, :export
    def initialize(args)
      @page = args[:page] || 1
      @per = args[:per] || 10
      @export = args[:export] || false
      @company_id = args[:company_id]
      @stock_location_ids = args[:stock_location_ids] || []
      date_s = args[:date_start] || 1.month.ago
      @zone = Spree::Company.find_by_id(@company_id).try(:time_zone) || 'UTC'
      tz_offset = ActiveSupport::TimeZone.new(@zone).now.utc_offset
      @date_start = date_s.beginning_of_day - tz_offset
      date_e = args[:date_end] || Time.current
      @date_end = date_e.end_of_day - tz_offset
      @items = []

      perform
    end

    def stock_location_names
      data_source.pluck(:stock_location_id, :stock_location_name)
                 .uniq.to_h
    end

    private

    def pagination_variables(result)
      @total_pages = result.total_pages
      @current_page = result.current_page
      @prev_page = result.prev_page
      @next_page = result.next_page
      @limit_value = result.limit_value
    end

    # support pagination for variants
    def variant_ids
      from_second = data_source(full: true).pluck(:variant_id).uniq
      result = Spree::Variant.where(id: from_second)
                             .order('LOWER(sku) ASC')
                             .page(@page)
                             .per(@per)
      pagination_variables(result)
      result.pluck(:id)
    end

    def query_where(full)
      return @query_where if @query_where

      @query_where = { originator_created_at: @date_start..@date_end,
                       company_id: @company_id }

      @query_where[:variant_id] = variant_ids if full == false

      return @query_where unless @stock_location_ids.present?

      @query_where[:stock_location_id] = @stock_location_ids
      @query_where
    end

    def perform
      create_items
      sort_items_by_name
    end

    def sort_items_by_name
      items.sort_by! { |e| e.sku.downcase }
    end

    def create_items
      data_source
        .select_as_hash(:variant_id, :item_variant_sku, :item_variant_name)
        .distinct.each { |line| items << DetailItem.new(line, data_source) }
    end

    def data_source(full: false)
      return @data_source if @data_source

      full = true if @export
      @data_source =
        Spree::InventoryChangeHistory
        .where(query_where(full))
        .order(originator_updated_at: :asc).to_a
      @data_source
    end
  end
end
