Spree::OrderUpdater.class_eval do

  def update_item_total
    order.item_total = line_items.sum('(price - price_discount) * quantity')
    update_order_total
  end

  #Using Time.current in favor of Time.now
  def persist_totals(options = { update_balance: true })
    order.move_balance_and_credit if (order.total_was != order.total) && \
                                     order.approved? && options[:update_balance]
    order.update_columns(
      payment_state: order.payment_state,
      shipment_state: order.shipment_state,
      item_total: order.item_total,
      item_count: order.item_count,
      adjustment_total: order.adjustment_total,
      included_tax_total: order.included_tax_total,
      additional_tax_total: order.additional_tax_total,
      payment_total: order.payment_total,
      shipment_total: order.shipment_total,
      promo_total: order.promo_total,
      total: order.total,
      updated_at: Time.current
    )
  end

  def update(options = { update_balance: true })
    update_totals
    if order.completed?
      update_payment_state
      update_shipments
      update_shipment_state
    end
    run_hooks
    persist_totals(options)
  end

  def update_shipments
    shipments.each do |shipment|
      next unless shipment.persisted?
      shipment.update!(order)
      begin
        shipment.refresh_rates
      rescue Spree::ShippingError
        next
      end
      shipment.update_amounts
    end
  end

  def update_shipment_total
    if order.recalculate_shipping? && shipments.last.try(:shipping_method) != order.shipping_method
      order.shipment_total = 0 unless order.override_shipment_cost
    else
      order.shipment_total = shipments.sum(:cost) unless order.override_shipment_cost
    end
    update_order_total
  end

  # Updates the +payment_state+ attribute according to the following logic:
  #
  # paid          when 'payment_total' is equal to 'total'
  # pending       when 'payment_total + pending_balance' is equal to 'total'
  # balance_due   when 'payment_total + pending_balance' is less than 'total'
  # credit_owed   when 'payment_total' is greater than 'total'
  # failed        when most recent payment is in the failed state
  # void          when order is canceled and 'payment_total' is equal to zero
  #
  # The +payment_state+ value helps with reporting, etc. since it provides a quick and easy way to locate Orders needing attention.
  def update_payment_state
    last_state = order.payment_state
    if payments.present? && payments.valid.size == 0
      order.payment_state = 'failed'
    elsif ['canceled', 'void'].include?(order.state) && order.payment_total == 0
      order.payment_state = 'void'
    elsif !order.outstanding_balance?
      order.payment_state = 'paid'
    elsif order.outstanding_balance < 0
      order.payment_state = 'credit_owed'
    elsif order.final_payments_pending?
      order.payment_state = 'pending'
    elsif order.outstanding_balance > 0
      order.payment_state = 'balance_due'
    end
    order.state_changed('payment') if last_state != order.payment_state
    order.payment_state
  end

  def update_invoice
    order.update_invoice if order.invoice.present?
  end

end
