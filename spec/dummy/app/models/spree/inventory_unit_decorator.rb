Spree::InventoryUnit.class_eval do
  belongs_to :lot, class_name: 'Spree::Lot',
                   foreign_key: :lot_id, primary_key: :id

  validates :quantity, numericality: { greater_than_or_equal_to: 0 }

  scope :backordered_per_variant, ->(stock_item) do
    includes(shipment: :order)
      .where("spree_shipments.state != 'canceled'").references(:shipment)
      .where(variant_id: stock_item.variant_id)
      .where('spree_orders.completed_at is not null')
      .backordered.order('spree_orders.completed_at ASC')
  end

  # state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine initial: :on_hand do
    state :backordered

    event :ship do
      transition to: :shipped, if: :allow_ship?
    end

    event :return do
      transition to: :returned, from: :shipped
    end
  end

  def remove(count)
    count = quantity if count > quantity

    self.quantity -= count
    quantity.zero? ? destroy : save!

    count
  end

  # Splits `count` units into a new duplicate (other than quantity) record.
  # The new record is yielded before saving, and the saved record is
  # returned.
  def split!(count)
    raise ArgumentError if count <= 0
    count = remove(count)
    Spree::InventoryUnit.create! do |unit|
      unit.quantity = count
      unit.variant_id = variant_id
      unit.line_item_id = line_item_id
      unit.shipment_id = shipment_id
      unit.state = state
      unit.order_id = order_id
      unit.lot_id = lot_id
      yield unit if block_given?
    end
  end

  def fill_backorders(count)
    raise 'item not backordered' unless backordered?
    return if count.zero?
    split!(count) do |unit|
      unit.state = 'on_hand'
    end.quantity
  end

  def percentage_of_line_item
    item = line_item.variant
    if item.has_parts?
      total_value = line_item.quantity_by_variant.map { |part, quantity| part.price * quantity }.sum
      variant.price / total_value
    else
      1 / BigDecimal.new(line_item.quantity)
    end
  end

  def fulfill_from_other_orders(today = Time.current.to_date)
    return unless order && variant && shipment
    return unless sufficient_on_hand?
    qty_to_exchange = quantity
    units = Spree::InventoryUnit.joins(:order, :shipment)
                        .on_hand
                        .where('spree_orders.delivery_date >= ?', today)
                        .where('spree_orders.id <> ?', order_id)
                        .where('spree_orders.state IN (?)', %w[complete approved])
                        .where('spree_inventory_units.variant_id = ?', variant_id)
                        .where('spree_shipments.stock_location_id = ?', shipment.stock_location_id)
                        .order('spree_orders.delivery_date desc, completed_at desc, created_at desc')
    units.each do |unit|
      qty_to_exchange = unit.exchange_to_backordered(qty_to_exchange)
      break if qty_to_exchange.zero?
    end
    if qty_to_exchange.zero?
      update_columns(state: 'on_hand')
      true
    else
      false
    end
  end

  def exchange_to_backordered(qty_to_exchange)
    if quantity == qty_to_exchange
      update_columns(state: 'backordered')
      qty_to_exchange = 0
    elsif quantity > qty_to_exchange
      update_columns(quantity: quantity - qty_to_exchange)
      new_unit = self.dup
      new_unit.quantity = qty_to_exchange
      new_unit.state = 'backordered'
      new_unit.save
      qty_to_exchange = 0
    else
      update_columns(state: 'backordered')
      qty_to_exchange -= quantity
    end

    qty_to_exchange
  end

  def sufficient_on_hand?
    on_hand = Spree::StockItem.where( variant_id: variant_id,
                            stock_location_id: shipment.stock_location_id
                          ).first.try(:on_hand)
    on_hand.to_d >= quantity
  end
end
