module InventoryHistory
  # Creating detail report class
  # line:Hash response example:
  # [{:reason_customer=>"Not set", :pack_size=>"10 lbs", :quantity=>#<BigDecimal:7fd561b82930,'-0.12E2',9(18)>},
  #  {:reason_customer=>"Not set", :pack_size=>"Not set", :quantity=>#<BigDecimal:7fd561b827f0,'-0.2E1',9(18)>},
  #  {:reason_customer=>"Not set", :pack_size=>"pack", :quantity=>#<BigDecimal:7fd56274e408,'-0.1E1',9(18)>},
  #  {:reason_customer=>"Not set", :pack_size=>"Case", :quantity=>#<BigDecimal:7fd56274e2a0,'0.1E1',9(18)>},
  #  {:reason_customer=>"add", :pack_size=>"Not set", :quantity=>#<BigDecimal:7fd56274e070,'0.1E2',9(18)>},
  #  {:reason_customer=>"Not set", :pack_size=>"10 lbs", :quantity=>#<BigDecimal:7fd56274df30,'-0.2E1',9(18)>}]
  class SummaryReport
    attr_reader :pack_size_names,
                :customer_type_reason_names,
                :result_for,
                :total_for,
                :overal_total

    BLANK_CUSTOMER_OR_PACK_SIZE_NAME = 'Not set'.freeze

    def initialize(args)
      @company_id = args[:company_id]
      @stock_location_ids = args[:stock_location_ids] || []
      @date_start = args[:date_start] || 1.month.ago
      @date_end = args[:date_end] || Time.current
      @lines = {}

      @invoices = {}
      @not_invoices = {}

      perform
    end

    def perform
      prepare_lines
      replace_nil_package_name_to_blank
      replace_nil_package_name_to_blank # for [nil,nil] conversion
      convert_lines_to_hash
    end

    def result_for(pack_size:, reason_customer:)
      summ = @lines.select { |row| row[:pack_size] == pack_size && row[:reason_customer] == reason_customer }
      return '0' if summ.blank?
      summ.inject(0) { |sum, l| sum + l[:quantity] }
    end

    def overal_total
      @lines.inject(0) { |sum, l| sum + l[:quantity] }
    end

    # return total for pack_size: '10 lbs' or reason_customer: 'Not set'
    def total_for(args)
      raise unless args.key?(:pack_size) || args.key?(:reason_customer)
      @lines.select { |l| l[args.keys.first] == args[args.keys.first] }.inject(0) { |sum, l| sum + l[:quantity] }
    end

    # return all posible pack_size names
    def pack_size_names
      return @pack_size_names if @pack_size_names
      names = @lines.inject([]) { |arr, l| arr << l[:pack_size] }.uniq.sort!
      @pack_size_names = place_blank_to_last(names)
    end

    # return all posible customer_type_names/reasons
    def customer_type_reason_names
      return @customer_type_reason_names if @customer_type_reason_names
      names = @lines.inject([]) { |arr, l| arr << l[:reason_customer] }.uniq.sort!
      @customer_type_reason_names = place_blank_to_last(names)
    end

    def place_blank_to_last(array)
      return array unless array.include? BLANK_CUSTOMER_OR_PACK_SIZE_NAME
      array.delete BLANK_CUSTOMER_OR_PACK_SIZE_NAME
      array << BLANK_CUSTOMER_OR_PACK_SIZE_NAME
    end

    private

    # [[nil, "10 lbs"], <BigDecimal:7fd547931f38,'-0.12E2',9(18)>]
    # as result [{:reason_customer=>nil, :pack_size=>"10 lbs", :quantity=>#<BigDecimal:7fd547931f38,'-0.12E2',9(18)>},
    def convert_lines_to_hash
      @lines = @lines.inject([]) { |arr, i| arr << { reason_customer: i[0][0], pack_size: i[0][1], quantity: i[1] } }
    end

    def replace_nil_package_name_to_blank
      @lines.keys.each do |key|
        replace_nil_to_blank(key)
      end
    end

    # [nil, "2", "3"] -> ["(Blank)", "2", "3"]
    def replace_nil_to_blank(data)
      data[data.index(nil)] = BLANK_CUSTOMER_OR_PACK_SIZE_NAME if data.index(nil)
      data[data.index('')] = BLANK_CUSTOMER_OR_PACK_SIZE_NAME if data.index('')
      data
    end

    def prepare_lines
      invoices = data_source.where(action: ACTION_TYPES[:invoice])
                            .group('customer_type_name', 'pack_size').sum('quantity')
      purchase_orders = data_source.where(action: ACTION_TYPES[:purchase_order])
                            .group('customer_type_name', 'pack_size').sum('quantity')
      not_invoices = data_source.where.not(action: [ACTION_TYPES[:invoice], ACTION_TYPES[:purchase_orders]])
                                .group('reason', 'pack_size').sum('quantity')
      @lines.merge!(invoices).merge!(purchase_orders).merge!(not_invoices)
    end

    def data_source(date_start: @date_start, date_end: @date_end,
                    stock_location_ids: @stock_location_ids, company_id: @company_id)
      return @data_source if @data_source
      zone = Spree::Company.find_by_id(@company_id).try(:time_zone) || 'UTC'
      tz_offset = ActiveSupport::TimeZone.new(zone).now.utc_offset
      date_start = date_start.beginning_of_day - tz_offset
      date_end = date_end.end_of_day - tz_offset
      query_where = {
        originator_created_at: date_start..date_end,
        company_id: company_id
      }
      query_where[:stock_location_id] = stock_location_ids if stock_location_ids.present?

      @data_source = Spree::InventoryChangeHistory.where(query_where)
    end
  end
end
