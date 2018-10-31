module Integrations
  module Tax
    def process_for(object)
      return unless object.try(:order).try(:account).try(:taxable)
      return unless tax_lines
      remove_current_adjustments(object)
      create_adjustment_for(object, tax_lines)
    end

    def process_for_order(order)
      return unless order.try(:account).try(:taxable)
      return unless tax_lines
      @order = order.reload
      return if @order.refunds.any?
      create_tax_rates
      create_adjustments_for_line_items(order.line_items)
    end

    private

    def create_adjustments_for_line_items(items)
      items.each do |item|
        remove_current_adjustments(item)
        line = @data['line_items'].detect { |li| li['product_id'] == item.sku }
        create_adjustment_for(item, line['tax_lines']) if line
      end
    end

    def create_adjustment_for(item, tax_lines)
      tax_lines.each do |tax_line|
        line_tax_rate = tax_rate(tax_line[:title], tax_line[:rate].to_d)
        line_tax_rate.adjust(item.order, item)
        override_adjustment_amount(item, line_tax_rate, tax_line[:price])
      end
    end

    def find_adjustment_for(item, item_tax_rate)
      item.adjustments.find_by(source: item_tax_rate)
    end

    def override_adjustment_amount(item, item_tax_rate, amount)
      return unless item_tax_rate || item || amount
      adjustment = find_adjustment_for(item, item_tax_rate)
      return unless adjustment
      adjustment.update(amount: amount.to_d)
      adjustment.close!
    end

    def tax_rate(name, amount)
      rate = vendor_object
             .tax_rates
             .find_by(tax_category_id: sync_item_tax_category.id,
                      name: name,
                      amount: amount)
      return rate if rate
      raise Error, I18n.t('integrations.tax_rate_not_found')
    end

    def remove_current_adjustments(adjustable)
      Spree::Adjustment.where(adjustable: adjustable).tax.destroy_all
    end

    def create_tax_rates
      tax_lines.each do |tax_line|
        rate = vendor_object
               .tax_rates
               .find_or_initialize_by(tax_category_id: sync_item_tax_category.id,
                                      name: tax_line[:title],
                                      amount: tax_line[:rate].to_d)
        next unless rate.new_record?
        rate.zone = sync_item_tax_zone || @order.tax_zone
        rate.calculator_type = 'Spree::Calculator::DefaultTax'
        rate.save!
      end
    end

    def add_tax_adjustment_for_shipments
      @order.shipments.each do |shipment|
        create_adjustment_for(shipment)
      end
    end

    def add_tax_adjustment_for_line_items
      @order.line_items.each do |line_item|
      end
    end

    def assign_tax_category_for_variant(variant)
      variant.update_column(:tax_category_id, sync_item_tax_category.id)
    end
  end
end
