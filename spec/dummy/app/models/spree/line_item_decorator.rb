Spree::LineItem.class_eval do
  include Spree::Integrationable
  include Spree::LineItem::Weight
  include Spree::LineItem::Lots
  include Spree::LineItem::Purchase

  has_one :vendor, through: :order
  has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy
  has_many :all_lots, class_name: "Spree::Lot", foreign_key: :variant_id, primary_key: :variant_id
  has_many :line_item_lots, class_name: "Spree::LineItemLots", foreign_key: :line_item_id, primary_key: :id, dependent: :destroy
  has_many :lots, through: :line_item_lots, source: :lot
  belongs_to :transaction_class, class_name: "Spree::TransactionClass", foreign_key: :txn_class_id, primary_key: :id
  has_many :ordered_parts, dependent: :destroy

  has_paper_trail class_name: 'Spree::Version'#, unless: Proc.new { |line_item| line_item.order.try(:state) == 'cart' }
                                              # can use above Proc if we don't care about the line_item state before Submitted
                                              # but that means we'd only see changes
  accepts_nested_attributes_for :inventory_units
  accepts_nested_attributes_for :line_item_lots

  before_create :set_pack_size
  after_update :freeze_parts, if: :quantity_changed?
  after_update :auto_assign_lots, if: :quantity_changed?

  clear_validators!
  validates :variant, :item_name, presence: true
  validates :price, numericality: true
  validates_with Spree::Stock::AvailabilityValidator
  validate :ensure_proper_currency
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  validate :step_size

  self.whitelisted_ransackable_attributes += %w[item_name ordered_qty shipped_qty quantity total custom_price discount_price amount lot_number pack_size position]
  self.whitelisted_ransackable_associations += %w[product lots]

  ransacker :amount do
    Arel.sql('amount')
  end
  ransacker :discount_price do
    Arel.sql('discount_price')
  end

  def self.view_editable_attributes
    #should return array of attributes
    [:lot_number]
  end

  def self.company_sort(company, order_by = nil)
    default = 'spree_line_items.position asc'
    order_by ||= company.try(:cva).try(:line_item_default_sql_sort)

    order_by.blank? ? default : order_by
  end

  def copy_tax_category
    return self.tax_category if self.tax_category
    if order.selectable_tax_categories? && order.account.present? && variant.try(:taxable?)
      self.tax_category = order.account.tax_category
    end

    return self.tax_category if self.tax_category

    if variant
      self.tax_category = variant.tax_category
    end
  end

  def copy_price
    if variant
      self.price = variant.price if price.nil?
      self.cost_price = variant.current_cost_price if cost_price.nil?
      self.currency = variant.currency if currency.nil?
    end
  end

  def fully_qualified_description
    if self.variant.product.variants.any?
      "#{self.variant.product.name} (#{self.variant.option_values.map{|ov| ov.presentation}.join(', ')})"
    else
      "#{self.variant.product.name}"
    end
  end

  def amount
    discount_price * quantity
  end

  def shipped_amount
    discount_price * shipped_qty
  end

  def discount_price
    price - price_discount
  end

  def update_adjustments
    if quantity_changed? || price_changed?
      update_price_discount
      recalculate_adjustments
      update_tax_charge unless self.order.account.try(:is_tax_exempt?)# Called to ensure pre_tax_amount is updated.
    elsif tax_category_id_changed?
      recalculate_adjustments
      update_tax_charge unless self.order.account.try(:is_tax_exempt?)
    end
  end

  def update_tax_charge
    Spree::TaxRate.adjust(order, [self]) unless self.order.account.try(:is_tax_exempt?)
  end

  def update_price_discount
    price_discount = 0
    if self.price == variant.price #do not check if the price has been manually overridden
      avv = Spree::AccountViewableVariant.find_by(account_id: self.order.account_id, variant_id: self.variant_id)
      if avv
        if avv.recalculating < Spree::AccountViewableVariant::RecalculatingStatus['complete']
          avv.cache_price
          avv.reload
        end
        price_discount = self.price - avv.price
      end
    end
    self.update_columns(price_discount: price_discount)
  end

  def is_eligible_discount?(promotion)
    eligibility_errors = [];

    promotion.rules.each do |rule|
      case rule.type
      when "Spree::Promotion::Rules::Account"
        unless rule.account_ids.include?(self.order.account.id)
          eligibility_errors.push('no applicable self.order.accounts')
        else
          return true if promotion.match_policy == 'any'
        end
      when "Spree::Promotion::Rules::Product"
        unless self.product && rule.product_ids.include?(self.product.id)
          eligibility_errors.push('no applicable self.products')
        else
          return true if promotion.match_policy == 'any'
        end
      when "Spree::Promotion::Rules::Variant"
        unless self.variant && rule.variant_ids.include?(self.variant_id)
          eligibility_errors.push('no applicable self.products')
        else
          return true if promotion.match_policy == 'any'
        end
      when "Spree::Promotion::Rules::Taxon"
        unless self.product && rule.taxon_ids.any?{|taxon_id| self.product.taxons.any?{|taxon| taxon.id == taxon_id}}
          eligibility_errors.push('no applicable taxons')
        else
          return true if promotion.match_policy == 'any'
        end
      else
          eligibility_errors.push('should be advertised')
      end
    end

    eligibility_errors.empty?
  end

  def is_past_cutoff?(date = nil)
    date ||= order.delivery_date
    variant.is_past_cutoff?(date)
  end

  def quantity_by_variant
    if variant.is_bundle?
      if part_line_items.any?
        quantity_with_part_line_items(quantity)
      else
        quantity_without_part_line_items(quantity)
      end
    else
      { variant => quantity }
    end
  end

  def assign_lot_by_unit_count(lot_id)
    unit_lot_count = self.inventory_units.where(lot_id: lot_id).count
    line_lot = self.line_item_lots.find_or_initialize_by(lot_id: lot_id)
    line_lot.count = unit_lot_count
    line_lot.save!
  end

  def update_inventory
    if (changed? || target_shipment.present? || order.shipments.present?)
      # target_shipment ||= order.shipments.first
      if self.variant.track_inventory
        Spree::OrderInventory.new(order, self).verify(target_shipment)
      else
        Spree::OrderInventoryAssembly.new(self).verify(target_shipment)
      end
    end
  end

  def backordered?
    self.inventory_units.backordered.any?
  end

  def unit_sum(var = nil)
    var ||= self.variant
    self.inventory_units.where(variant: var).sum(:quantity)
  end

  def display_stock_level
    return '' unless States[order.state].between?(States['cart'], States['approved'])
    if States[order.state] < States['complete']
      return variant.display_stock_level(false, order.default_stock_location, quantity, self)
    end
    backordered? ? Spree.t(:backordered) : ''
  end

  def fix_stock
    return unless variant.should_track_inventory?
    return unless States[order.state] >= States['complete']
    shipment = order.shipments.first
    return unless shipment
    si = Spree::StockItem.where(variant_id: variant_id, stock_location_id: shipment.stock_location_id).first
    item_qty = order.line_items.select{|li| li.variant_id == variant_id }.map(&:quantity).inject(:+)
    movement_qty = Spree::StockMovement.where(
      stock_item_id: si.id,
      originator_id: shipment.id,
      originator_type: 'Spree::Shipment'
    ).sum(:quantity)

    return if (-1 * movement_qty) == item_qty

    qty_to_move = movement_qty - item_qty

    transaction do
      si.adjust_count_on_hand(qty_to_move)
      Spree::StockMovement.create(
        originator_id: shipment.id,
        originator_type: 'Spree::Shipment',
        quantity: qty_to_move,
        stock_item_id: si.id
      )
    end
  end

  private

  def quantity_without_part_line_items(quantity)
    variant.parts_variants.each_with_object({}) do |pv, hash|
      hash[pv.part] = pv.count * quantity
    end
  end

  def set_pack_size
    self.pack_size = self.variant.try(:pack_size).to_s if self.pack_size.blank?
  end

  def step_size
    return true if self.quantity % variant.step_size == 0
    errors.add(:base, "Must order #{variant.flat_or_nested_name} in multiples of #{variant.step_size}")
    false
  end

end
