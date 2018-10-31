module Integrations
  module Refund
    attr_reader :order
    def process_for(processed_order)
      @order = processed_order.reload
      return unless @data['refund_line_items'].present?
      return add_refund_adjustment if @data['restock'] == false

      @order.update_columns(completed_at: Time.current) unless @order.completed_at
      handle_lines_inventory if @order.refunds.blank?
      update_order_totals
    end

    def refund_adjustment_amount
      amount = 0.00
      @data['refund_line_items'].each do |line|
        amount += line['subtotal']
        amount += line['total_tax']
      end
      amount * -1
    end

    def add_refund_adjustment
      return if refunded_adjustment

      adjustment = order.adjustments.build(
        order: order, amount: refund_adjustment_amount.to_f, label: 'Refunded'
      )
      adjustment.save!
      adjustment.close!
    end

    def refunded_adjustment
      order.adjustments.find_by(label: 'Refunded')
    end

    def restocked_taxes_on_refund
      return unless refunded_adjustment

      refunded_adjustment.destroy
    end

    def refund_sum
      sum = 0
      @data['refund_line_items'].each do |refund_line_item|
        sum += refund_line_item[:total_tax]
      end
      sum.to_d
    end

    def update_order_totals
      order.item_count = order.quantity
      order.updater.recalculate_adjustments
      order.persist_totals
    end

    def handle_lines_inventory
      @data['refund_line_items'].each do |refund_line_item|
        handle_line_inventory(refund_line_item)
      end
      restocked_taxes_on_refund
    end

    def handle_line_inventory(refund_line_item)
      line_item = order.line_items
                       .joins(:variant)
                       .find_by('spree_variants.sku = ?',
                                refund_line_item['sku'])
      raise I18n.t('integrations.no_find_line_items') unless line_item
      real_quantity = line_item.quantity - refund_line_item['refund_quantity']
      line_item.update(quantity: real_quantity)
    end
  end
end
