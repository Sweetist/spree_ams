module Production
  # Creating production_by_customer report class
  class ByCustomerReport
    attr_reader :accounts, :variants, :result_for
    def initialize(args)
      @vendor = args[:vendor]
      @account_ids = args[:account_ids] || []
      @date_start = args[:date_start] || 1.month.ago
      @date_end = args[:date_end] || Time.current
      @order_states = args[:order_states]
    end

    def result_for(account_id:, variant_sku:)
      summ = data_source.detect { |row| row['sku'] == variant_sku && row['account_id'] == account_id.to_s }
      return '0' if summ.blank?
      summ['sum']
    end

    def accounts
      return @accounts if @accounts
      data_source.inject([]) {|arr, row| arr << { name: row['account_name'], id: row['account_id']}}.uniq
    end

    def variants
      return @variants if @variants
      data_source.inject([]) {|arr, row| arr << { sku: row['sku'], name: row['variant_name']}}.uniq
    end

    def data_source(date_start: @date_start, date_end: @date_end, order_states: @order_states,
                    account_ids: @account_ids, vendor: @vendor)
      return @data_source if @data_source
      # create Arel tables
      orders = Spree::Order.arel_table
      line_items = Spree::LineItem.arel_table
      variants = Spree::Variant.arel_table
      products = Spree::Product.arel_table
      accounts = Spree::Account.arel_table

      # join predicates
      line_items_variant_predicate = line_items[:variant_id].eq(variants[:id])
      order_account_predicate = orders[:account_id].eq(accounts[:id])
      order_line_item_predicate = line_items[:order_id].eq(orders[:id])

      # select attributes
      attribures = [variants[:sku],
                    variants[:full_display_name].as('variant_name'),
                    accounts[:fully_qualified_name].as('account_name'),
                    accounts[:id].as('account_id'),
                    line_items[:quantity].sum]

      # perform query
      query = variants.project(attribures)
                      .join(line_items).on(line_items_variant_predicate)
                      .join(orders).on(order_line_item_predicate)
                      .join(accounts).on(order_account_predicate)
                      .where(orders[:vendor_id].eq(vendor.id))
                      .where(orders[:delivery_date].gteq(date_start))
                      .where(orders[:delivery_date].lteq(date_end))
                      .where(accounts[:id].in(account_ids))
                      .where(orders[:state].in(order_states))
                      .group(variants[:sku], variants[:full_display_name], accounts[:fully_qualified_name], accounts[:id])

      @data_source = ActiveRecord::Base.connection.exec_query(query.to_sql)
    end
  end
end
