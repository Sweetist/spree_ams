Spree::StockItem.class_eval do
  include Spree::Integrationable
  has_many :stock_item_lots, class_name: 'Spree::StockItemLots', foreign_key: :stock_item_id, primary_key: :id
  has_many :lots, through: :stock_item_lots, source: :lot

  alias_attribute :available, :count_on_hand

  self.whitelisted_ransackable_attributes = %w[count_on_hand available on_hand committed]
  self.whitelisted_ransackable_associations = %w[stock_location]

  def self.low_stock
    joins(:variant, :stock_location)
    .where('spree_stock_locations.active = ?', true)
    .where('spree_variants.variant_type in (?)', INVENTORY_TYPES.keys)
    .where('min_stock_level IS NOT NULL AND count_on_hand <= min_stock_level')
  end

  def self.active
    joins(:stock_location)
    .where('spree_stock_locations.active = ?', true)
  end

  def adjust_count_on_hand(value, lot = nil, backorder_fill_qty = nil)
    with_lock do
      set_count_on_hand((count_on_hand + value), lot, backorder_fill_qty)
    end
  end

  def update_calculated_counts
    calculated_committed = calculate_committed

    update_columns(
      committed: calculated_committed,
      on_hand: calculate_on_hand(calculated_committed)
    )
  end

  def set_count_on_hand(value, lot = nil, backorder_fill_qty = nil)
    self.count_on_hand = value
    diff = count_on_hand - count_on_hand_was
    if lot.try(:id)
      stock_item_lot = stock_item_lots.find_or_initialize_by(lot_id: lot.id)
      process_backorders(diff, stock_item_lot, backorder_fill_qty)
    else
      process_backorders(diff, nil, backorder_fill_qty)
    end

    self.committed = calculate_committed
    self.on_hand = calculate_on_hand

    save!
  end

  def low_stock?
    return false if min_stock_level.nil?
    return false unless variant.should_track_inventory?
    return false unless stock_location.active?

    count_on_hand <= min_stock_level
  end

  def process_backorders(number, stock_item_lot = nil, backorder_fill_qty = nil)
    backorder_fill_qty ||= number
    if backorder_fill_qty > 0
      units = backordered_inventory_units
      qty_to_fill = 0
      line_item_ids = []
      backordered_order_ids = []
      unit_ids = []
      unit_to_split = nil
      units.each do |unit|
        qty_to_fill += unit.quantity
        if qty_to_fill <= backorder_fill_qty
          unit_ids << unit.id
          line_item_ids << unit.line_item_id
          backordered_order_ids << unit.order_id
          break if backorder_fill_qty - qty_to_fill == 0
        else
          qty_to_fill -= unit.quantity
          unit_to_split = unit
          break
        end
      end

      units.where(id: unit_ids).update_all(state: 'on_hand', lot_id: stock_item_lot.try(:lot_id))
      Spree::Order.where(id: backordered_order_ids).each(&:fulfill!) unless backordered_order_ids.empty?
      if stock_item_lot.present?
        adjust_lots_after_backorders(line_item_ids, stock_item_lot, qty_to_fill)
      end
      split_unit(unit_to_split, backorder_fill_qty - qty_to_fill)
    end
  end

  def adjust_lots_after_backorders(line_item_ids, stock_item_lot, number)
    Spree::LineItem
      .includes(:inventory_units)
      .where(id: line_item_ids)
      .each { |li| li.assign_lot_by_unit_count(stock_item_lot.lot_id) }
  end

  def backordered_inventory_units(sort_by = 'completed_at')
    Spree::InventoryUnit.joins(:shipment, :order)
      .where('spree_inventory_units.state = ?', 'backordered')
      .where('spree_inventory_units.variant_id = ?', self.variant_id)
      .where('spree_shipments.stock_location_id = ?', self.stock_location_id)
      .where.not('spree_orders.state IN (?)', ['canceled', 'void'])
      .order("spree_orders.#{sort_by} ASC")
  end

  def split_unit(unit, qty)
    return if unit.nil?
    unit.fill_backorders(qty)
  end

  def unassigned_inventory_count
    [count_on_hand - unused_lots_count, 0].max
  end

  def unused_lots_count
    [stock_item_lots.sum(:count) - committed_lot_count, 0].max
  end

  def committed_lot_count
    company = self.variant.try(:vendor)
    return 0 unless company

    Spree::LineItemLots.includes(line_item: :order)
      .where('spree_line_item_lots.lot_id in (?)', self.lot_ids)
      .where('spree_orders.state in (?) and spree_orders.vendor_id = ?',
              ['complete', 'approved'], company.id)
      .sum(:count)
  end

  def calculate_committed
    Spree::LineItem.joins(order: :shipments)
                   .where('spree_line_items.variant_id = ?', self.variant_id)
                   .where('spree_orders.state in (?)', ['complete', 'approved'])
                   .where('spree_shipments.stock_location_id = ?', self.stock_location_id)
                   .sum('spree_line_items.quantity')
  end

  def committed_by_date(start_date, end_date)
    Spree::LineItem.joins(order: :shipments)
                   .where('spree_line_items.variant_id = ?', self.variant_id)
                   .where('spree_orders.state in (?)', ['complete', 'approved'])
                   .where('spree_shipments.stock_location_id = ?', self.stock_location_id)
                   .where('spree_orders.delivery_date >= ?', start_date)
                   .where('spree_orders.delivery_date <= ?', end_date)
                   .sum('spree_line_items.quantity')
  end

  def total_committed_by_date(start_date, end_date)
    Spree::LineItem.joins(order: :shipments)
                   .where('spree_line_items.variant_id = ?', self.variant_id)
                   .where('spree_orders.state in (?)', ['complete', 'approved'])
                   .where('spree_orders.delivery_date >= ?', start_date)
                   .where('spree_orders.delivery_date <= ?', end_date)
                   .sum('spree_line_items.quantity')
  end

  def calculate_on_hand(committed_count = self.committed)
    [available + committed_count, 0].max
  end

end
