Spree::OrderInventory.class_eval do
  def verify(shipment = nil)
    if order.completed? || shipment.present?
      shipment = determine_target_shipment unless shipment
      line_qty = line_item.quantity
      current_unit_qty = inventory_units.sum(:quantity)

      quantity = line_item.quantity - current_unit_qty
      if quantity > 0
        if shipment
          shipment.save unless shipment.persisted?
          add_to_shipment(shipment, quantity)
        end
      elsif quantity < 0
        remove(-quantity, shipment) if shipment
      end
    end
  end

  def determine_target_shipment
    shipment = order.shipments.detect do |shipment|
      shipment.ready_or_pending? && shipment.include?(variant)
    end

    shipment ||= order.shipments.detect do |shipment|
      shipment.ready_or_pending? && variant.stock_location_ids.include?(shipment.stock_location_id)
    end

    if shipment.nil? && Sweet::Application.config.x.adjust_inventory_after_ship
      shipment = order.shipments.detect do |shipment|
        shipment.shipped_or_received? && shipment.include?(variant)
      end

      shipment ||= order.shipments.detect do |shipment|
        shipment.shipped_or_received? && variant.stock_location_ids.include?(shipment.stock_location_id)
      end
    end

    shipment
  end

  def add_to_shipment(shipment, quantity)
    if shipment.shipped? && Sweet::Application.config.x.adjust_inventory_after_ship
      shipment.adjust_inventory('shipped',     variant, line_item, quantity)
    elsif variant.should_track_inventory?
      on_hand, back_order = shipment.stock_location.fill_status(variant, quantity)

      shipment.adjust_inventory('on_hand',     variant, line_item, on_hand)
      shipment.adjust_inventory('backordered', variant, line_item, back_order)
    else
      shipment.adjust_inventory('on_hand',     variant, line_item, quantity)
    end
    # adding to this shipment, and removing from stock_location
    if order.completed?
      shipment.stock_location.unstock(variant, quantity, shipment)
    end

    quantity
  end

  def remove_from_shipment(shipment, quantity)
    return 0 if quantity.zero? || (shipment.shipped? && !Sweet::Application.config.x.adjust_inventory_after_ship)

    if Sweet::Application.config.x.adjust_inventory_after_ship
      shipment_units = shipment.inventory_units_for_item(line_item, variant)
    else
      shipment_units = shipment.inventory_units_for_item(line_item, variant)
                               .where.not(state: 'shipped')
    end

    removed_quantity = 0
    removed_backorderd = remove_units_by_state(shipment, shipment_units, quantity, 'backordered')
    removed_quantity += removed_backorderd
    removed_quantity += remove_units_by_state(shipment, shipment_units, quantity - removed_quantity, 'on_hand')
    removed_quantity += remove_units_by_state(shipment, shipment_units, quantity - removed_quantity, 'shipped')

    shipment.destroy if shipment.inventory_units.count.zero?
    # removing this from shipment, and adding to stock_location
    if order.completed?
      shipment.stock_location.restock(variant, removed_quantity, shipment, nil, removed_quantity - removed_backorderd)
    end

    removed_quantity
  end

  def remove_units_by_state(shipment, units, quantity, state)
    return 0 if quantity.zero?
    qty = units.send(state).sum(:quantity)
    if qty >= quantity
      shipment.adjust_inventory(state, variant, line_item, -quantity)
    else
      shipment.adjust_inventory(state, variant, line_item, -qty)
    end
  end

  private

  def remove(quantity, shipment = nil)
    if shipment.present?
      remove_from_shipment(shipment, quantity)
    else
      order.shipments.each do |shippment|
        break if quantity.zero?
        quantity -= remove_from_shipment(shippment, quantity)
      end
    end
  end
end
