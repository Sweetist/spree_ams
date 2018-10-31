module InventoryHistory
  class DetailItemLine
    attr_accessor :destination_stock_location_id, :destination_quantity,
                  :destination_qty_on_hand, :source_quantity, :source_qty_on_hand,
                  :transaction_type, :total_qty_on_hand

    LINE_ATTRIBUTES_RELATION = {
      variant_id: 'variant_id',
      date: 'originator_updated_at',
      action: 'action',
      order_number: 'originator_number',
      customer: 'customer_name',
      reason: 'reason',
      customer_type: 'customer_type_name',
      quantity: 'quantity',
      qty_on_hand: 'quantity_on_hand',
      stock_location_id: 'stock_location_id',
      originator_id: 'originator_id',
      originator_type: 'originator_type'
    }.freeze

    def initialize(line, total_qoh_for_line)
      create_attributes(line.attributes)
      @destination_stock_location_id = nil
      @total_qty_on_hand = total_qoh_for_line
    end

    def transaction_type
      return action.capitalize unless InventoryHistory::ACTION_TYPES.key(action)
      InventoryHistory::ACTION_TYPES.key(action).to_s.titleize
    end

    def line_for_export(vendor, stock_location_ids)
      line_base = [
        vendor.to_vendor_date(date),
        transaction_type.to_s.titleize,
        order_number,
        customer || reason,
        customer_type
      ]
      stock_location_ids.each do |stock_id|
        stock_qty = nil
        stock_qty_on_hand = nil
        if stock_location_id == stock_id
          stock_qty = source_quantity || quantity
          stock_qty_on_hand = source_qty_on_hand || qty_on_hand
        end
        if destination_stock_location_id == stock_id
          stock_qty = destination_quantity
          stock_qty_on_hand = destination_qty_on_hand
        end
        line_base += [
          stock_qty,
          stock_qty_on_hand
        ]
      end
      line_base += [
        quantity,
        total_qty_on_hand
      ]
    end

    private

    def create_attributes(raw_line_attributs)
      LINE_ATTRIBUTES_RELATION.each_pair do |attribute, table_key|
        singleton_class.class_eval { attr_accessor attribute }
        instance_variable_set('@' + attribute.to_s, raw_line_attributs[table_key])
      end
    end

    def create_method(name, &block)
      self.class.send(:define_method, name, &block)
    end
  end
end
