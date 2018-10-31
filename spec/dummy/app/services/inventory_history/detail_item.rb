module InventoryHistory
  class DetailItem
    attr_reader :lines, :id, :title, :total_qty, :sku
    def initialize(line, data_source)
      @id = line['variant_id']
      @data_source = data_source.where(variant_id: @id)
      @lines = []
      @sku = line['item_variant_sku']
      @title = line['item_variant_name']
      @title = "#{@sku} (#{@title})" if @sku.present?

      add_lines_to_item
    end

    def lines
      @lines.sort_by!(&:date)
    end

    def total_qty
      sum = 0
      lines.each { |e| sum += e.quantity }
      sum
    end

    def start_total_qty_on_hand
      return 0 unless lines

      stock_location_ids.inject(0) { |sum, stock_id| sum + start_balance_for_stock_location(stock_id) }
    end

    def end_total_qty_on_hand
      return 0 unless lines

      stock_location_ids.inject(0) { |sum, stock_id| sum + end_balance_for_stock_location(stock_id) }
    end

    def start_balance_for_stock_location(stock_location_id)
      balance_line = @data_source.where(stock_location_id: stock_location_id)

      return 0 unless balance_line.any?
      balance_line.first.quantity_on_hand - balance_line.first.quantity
    end

    def end_balance_for_stock_location(stock_location_id)
      balance_line = @data_source.where(stock_location_id: stock_location_id)

      return 0 unless balance_line.any?
      balance_line.last.quantity_on_hand
    end

    private

    def line_exist?(new_line)
      lines.any? do |line|
        line.variant_id == new_line.variant_id && \
          line.originator_id == new_line.originator_id && \
          line.originator_type == new_line.originator_type
      end
    end

    def detect_line(new_line)
      lines.detect do |line|
        line.variant_id == new_line.variant_id && \
          line.originator_id == new_line.originator_id && \
          line.originator_type == new_line.originator_type
      end
    end

    def update_line_attributes_when_stock_transfer(line, new_line)
      line.destination_stock_location_id = new_line.stock_location_id
      line.destination_quantity = new_line.quantity
      line.destination_qty_on_hand = new_line.qty_on_hand
      line.source_quantity = line.quantity
      line.source_qty_on_hand = line.qty_on_hand
      line.qty_on_hand = new_line.qty_on_hand
      line.quantity = 0
    end

    def group_lines(new_line)
      line = detect_line(new_line)
      if new_line.quantity > 0 && new_line.action == ACTION_TYPES[:transfer]
        update_line_attributes_when_stock_transfer(line, new_line)
      else
        @lines << new_line
      end
    end

    def qoh(on_stock_location_id:, at_time:)
      stock_location_data = @data_source
                            .where(stock_location_id: on_stock_location_id)
                            .pluck(:originator_updated_at, :quantity_on_hand)

      result = stock_location_data.select { |k| k[0] <= at_time }

      return result.last[1] if result.any?
      start_balance_for_stock_location(on_stock_location_id)
    end

    def total_qoh_for(line)
      sum = 0
      stock_location_ids.each do |stock_location_id|
        sum += qoh(on_stock_location_id: stock_location_id,
                   at_time: line.originator_updated_at)
      end
      sum
    end

    def add(line)
      new_line = DetailItemLine.new(line, total_qoh_for(line))

      invoice = InventoryHistory::ACTION_TYPES[:invoice]
      purchase_order = InventoryHistory::ACTION_TYPES[:purchase_order]

      if new_line.action == invoice && line_exist?(new_line)
        new_line.action += ' update'
      elsif new_line.action == purchase_order && line_exist?(new_line)
        new_line.action += ' update'
      end

      return @lines << new_line unless line_exist?(new_line)
      group_lines(new_line)
    end

    def add_lines_to_item
      @data_source.each { |line| add(line) }
    end

    def stock_location_ids
      @data_source.pluck(:stock_location_id).uniq
    end
  end
end
