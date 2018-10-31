module Spree
  class Printables::Order::BillOfLadingView < Printables::BaseView

    def_delegators :@printable,
                   :email,
                   :po_number,
                   :bill_address,
                   :ship_address,
                   :tax_address,
                   :item_total,
                   :total,
                   :currency,
                   :payments,
                   :shipments

    def items
      lines = printable.line_items.ransack({})
      lines.sorts = printable.vendor.cva.try(:line_item_default_sort)

      lines.result.includes(line_item_lots: :lot).map do |item|
        Spree::Printables::Order::Item.new(assign_item_attributes(item))
      end
    end

    def number
      if printable.is_a?(Spree::Order)
        printable.display_number
      else
        printable.number
      end
    end

    def firstname
      printable.ship_address.try(:firstname).to_s
    end

    def lastname
      printable.ship_address.try(:lastname).to_s
    end

    def after_save_actions
    end
  end
end
