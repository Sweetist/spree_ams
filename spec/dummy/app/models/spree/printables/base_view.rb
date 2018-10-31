include Forwardable

module Spree
  class Printables::BaseView
    extend Forwardable
    extend Spree::DisplayMoney

    attr_reader :printable

    money_methods :item_total, :total

    def initialize(printable)
      @printable = printable
    end

    def assign_item_attributes(item)
      { sku: item.sku, name: item.item_name, price: item.discount_price,
        quantity: item.quantity, total: item.amount, currency: item.currency,
        lot_number: item.line_item_lots_text(item.line_item_lots, {sparse: true}), show_parts: item.variant.show_parts,
        parts: parts(item), pack_size: item.pack_size,
        unit_weight: item.variant.display_weight, total_weight: item.display_weight }
    end

    ItemPart = Struct.new(:flat_or_nested_name, :lot_number,
                          :part_qty, :total)

    def parts(item)
      return unless item.variant.parts
      parts = []
      item.variant.parts.each do |part|
        part_qty = item.variant.parts_variants
                       .find_by(part_id: part).try(:count)
        line_item_lots = item.lot_names_qty_for(part, for_pdf: true).join(';')
        parts << ItemPart.new(part.flat_or_nested_name,
                              line_item_lots || 'N/A',
                              part_qty, part_qty * item.quantity)
      end
      parts
    end

    def firstname
      raise NotImplementedError, 'Please implement firstname'
    end

    def lastname
      raise NotImplementedError, 'Please implement lastname'
    end

    def email
      raise NotImplementedError, 'Please implement email'
    end

    def total
      raise NotImplementedError, 'Please implement total'
    end

    def number
      raise NotImplementedError, 'Please implement number'
    end
  end
end
