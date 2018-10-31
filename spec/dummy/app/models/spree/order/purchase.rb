module Spree::Order::Purchase
  extend ActiveSupport::Concern

  included do
    before_validation :generate_po_number, on: :create, if: :purchase_order?

    DEFAULT_PO_ORDER_PREFIX = 'PO-'.freeze
    DEFAULT_PO_ORDER_LENGTH = 9

    belongs_to :po_stock_location, class_name: 'Spree::StockLocation',
                                   foreign_key: :po_stock_location_id,
                                   primary_key: :id
  end

  def restock_receive_at_location
    return unless po_stock_location
    line_items.includes(:line_item_lots).each do |line_item|
      next unless line_item.variant.should_track_inventory?
      restocked_qty = 0
      line_item.line_item_lots.each do |lil|
        qty_to_restock = [lil.count, line_item.quantity - restocked_qty].min
        next if qty_to_restock <= 0
        po_stock_location.restock(line_item.variant, qty_to_restock, self, lil.lot)
        restocked_qty += qty_to_restock
      end
      if restocked_qty < line_item.quantity
        po_stock_location.restock(line_item.variant, line_item.quantity - restocked_qty, self)
      end
    end
  end

  def unstock_receive_at_location
    line_items.includes(:line_item_lots).each do |line_item|
      next unless line_item.variant.should_track_inventory?
      unstocked_qty = 0

      line_item.line_item_lots.each do |lil|
        qty_to_unstock = [lil.count, line_item.quantity - unstocked_qty].min
        next if qty_to_unstock <= 0
        po_stock_location.unstock(line_item.variant, qty_to_unstock, self, lil.lot)
        unstocked_qty += qty_to_unstock
      end
      if unstocked_qty < line_item.quantity
        po_stock_location.unstock(line_item.variant, line_item.quantity - unstocked_qty, self)
      end
      line_item.line_item_lots.delete_all
    end
  end

  def update_variant_costs
    changed_variant_ids = line_items.map(&:update_variant_cost).compact.uniq
    return if changed_variant_ids.empty?
    customer.variants_including_master.joins(:parts_variants)
      .where(variant_type: BUILD_TYPES.keys)
      .where('spree_assemblies_parts.part_id IN (?)', changed_variant_ids)
      .each {|assembly| assembly.update_components_cost}
  end

  def purchase_order?
    order_type == 'purchase' ? true : false
  end

  def po_name_for_integration
    "PurchaseOrder: #{self.po_display_number} for: #{self.account.try(:fully_qualified_name)}"
  end

  # Example
  # PO1-VA0000000001
  # PO - default prefix
  # 1  - vendor_id
  # VA - customer prefix
  # 10 digits for number()
  def generate_po_number(options = {})
    options[:prefix] = po_prefix_scope
    options[:prefix] += customer.po_order_prefix.nil? ? "#{DEFAULT_PO_ORDER_PREFIX}" : "#{customer.po_order_prefix}"
    next_number = customer.po_order_next_number.to_s
    loop do
      self.po_number = "#{options[:prefix].to_s.strip}#{next_number}"
      # get original number length with padding
      len = next_number.length
      # increase numerical value
      next_number = next_number.to_i + 1
      # get length of numerical value
      len2 = next_number.to_s.length
      # get the number of zeros for padding after the number increases
      # need this for when number length increases Ex. 0009999 + 1 = 0010000
      pad_length = [len - len2, 0].max
      # reassemble next_number
      next_number = "#{'0' * pad_length}#{next_number}"

      break unless customer.purchase_orders.exists?(po_number: self.po_number)
    end

    customer.po_order_next_number = next_number
    customer.update_columns(invoice_settings: customer.invoice_settings)
    po_number
  end

  def po_display_number
    start = po_prefix_scope.length
    po_number.to_s.slice(start..-1)
  end

  def po_number_pattern(number = 0)
    added_zero = format("%0#{DEFAULT_PO_ORDER_LENGTH}d", number)
    "#{po_prefix_scope}#{customer.po_order_prefix}#{added_zero}"
  end

  def po_prefix_scope
    # "#{DEFAULT_PO_ORDER_PREFIX}#{vendor_id}-"
    ''
  end

  def set_to_purchase_order
    self.order_type = 'purchase'
    save
  end

  def add_vendor_to_purchasable_variants
    line_items.each(&:add_vendor_to_variant)
  end
end
