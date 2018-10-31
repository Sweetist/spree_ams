module Spree
  class Printables::Order::PurchaseOrderView < Printables::BaseView

    def_delegators :@printable,
                   :email,
                   :po_number,
                   :bill_address,
                   :ship_address,
                   :tax_address,
                   :item_total,
                   :item_count,
                   :total,
                   :currency,
                   :payments,
                   :shipments

    def items
      printable.line_items.map do |item|
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
