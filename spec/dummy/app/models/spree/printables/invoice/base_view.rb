include Forwardable

module Spree
  class Printables::Invoice::BaseView < Printables::BaseView
    extend Forwardable
    extend Spree::DisplayMoney

    attr_reader :printable

    money_methods :item_total, :total

    def bill_address
      raise NotImplementedError, 'Please implement bill_address'
    end

    def ship_address
      raise NotImplementedError, 'Please implement ship_address'
    end

    def tax_address
      raise NotImplementedError, 'Please implement tax_address'
    end

    def items
      raise NotImplementedError, 'Please implement items'
    end

    def item_total
      raise NotImplementedError, 'Please implement item_total'
    end

    def adjustments
      # adjustments = []
      # all_adjustments.group_by(&:label).each do |label, adjustment_group|
      #   adjustments << Spree::Printables::Invoice::Adjustment.new(
      #     label: label,
      #     amount: adjustment_group.map(&:amount).sum
      #   )
      # end
      # adjustments
      total - item_total
    end

    def shipments
      raise NotImplementedError, 'Please implement shipments'
    end

    def payments
      raise NotImplementedError, 'Please implement payments'
    end

    def shipping_methods
      if printable.is_a?(Spree::Invoice)
        if printable.multi_order?
          'Shipping'
        else
          printable.orders.first.shipments.map(&:shipping_method).keep_if{|shipping_method| shipping_method.present?}.map(&:name)
        end
      else
        printable.shipments.map(&:shipping_method).keep_if{|shipping_method| shipping_method.present?}.map(&:name)
      end
    end

    def number
      if printable.is_a?(Spree::Order)
        printable.display_number
      else
        printable.number
      end
    end

    def after_save_actions

    end

    private

    def increase_invoice_number!

    end

    def use_sequential_invoice_number?

    end
  end
end
