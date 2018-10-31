module Spree
  class Printables::Invoice::InvoiceView < Printables::Invoice::BaseView
    def_delegators :@printable,
                   :email,
                   :po_number,
                   :bill_address,
                   :ship_address,
                   :tax_address,
                   :item_total,
                   :adjustment_total,
                   :adjustments,
                   :shipment_adjustments,
                   :line_item_adjustments,
                   :promo_total,
                   :shipment_total,
                   :additional_tax_total,
                   :included_tax_total,
                   :total,
                   :currency,
                   :payments,
                   :multi_order,
                   :shipments

    def items
      if printable.multi_order
        printable.grouped_line_items.map do |item|
          Spree::Printables::Invoice::Item.new(assign_item_attributes(item))
        end
      else
        lines = printable.line_items.ransack({})
        lines.sorts = printable.vendor.cva.try(:line_item_default_sort)

        lines.result.includes(line_item_lots: :lot).map do |item|
          Spree::Printables::Invoice::Item.new(assign_item_attributes(item))
        end
      end
    end

    def firstname
      printable.ship_address.try(:firstname)
    end

    def lastname
      printable.ship_address.try(:lastname)
    end

    private

    def all_adjustments
      printable.all_adjustments.eligible
    end
  end
end
