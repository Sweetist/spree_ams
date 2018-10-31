Spree::StockLocation.class_eval do
  include Spree::Integrationable
  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
  has_many :lots, through: :stock_items, source: :lots
  has_many :stock_item_lots, through: :stock_items
  has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy

  validate :state_validate, :postal_code_validate,
           unless: proc { |a| a.name == 'Default' }
  validates :city, :zipcode,
            :country_id, :state_id, :vendor_id,
            presence: true,
            unless: proc { |a| a.name == 'Default' }
  validates :name, uniqueness: { scope: :vendor_id }
  validate :active_default

  self.whitelisted_ransackable_attributes = %w[name]
  self.whitelisted_ransackable_associations = %w[stock_items]

  def name_with_active_status
    return name if active?
    "#{name} (inactive)"
  end

  def restock(variant, quantity, originator = nil, lot = nil, backorder_fill_qty = nil)
    move(variant, quantity, originator, lot, backorder_fill_qty)
  end

  def unstock(variant, quantity, originator = nil, lot = nil, backorder_fill_qty = 0)
    move(variant, -quantity, originator, lot, backorder_fill_qty)
  end

  def move(variant, quantity, originator = nil, lot = nil, backorder_fill_qty = nil)
    stock_item = stock_item_or_create(variant)
    update_stock_item_quantity(stock_item, quantity, lot, backorder_fill_qty)
    stock_item.reload.stock_movements
              .create!( quantity: quantity,
                        originator: originator,
                        lot: lot )
    return unless lot
    stock_item_lot = stock_item_or_create(variant).stock_item_lots
                                                  .find_or_initialize_by(lot: lot)
    lot.move_qty(quantity, stock_item_lot)
  end

  def fill_status(variant, quantity)
    if item = stock_item(variant)
      if item.count_on_hand >= quantity
        on_hand = quantity
        backordered = 0
      elsif item.backorderable?
        on_hand = item.count_on_hand
        on_hand = 0 if on_hand < 0
        backordered = (quantity - on_hand)
      else
        item.errors.add(:base, "Insufficient stock at #{item.stock_location.name}")
        raise ActiveRecord::RecordInvalid.new(item)
      end

      [on_hand, backordered]
    else
      [0, 0]
    end
  end

  def restock_backordered(variant, quantity, originator = nil)
    item = stock_item_or_create(variant)
    item.update_columns(
      count_on_hand: item.count_on_hand + quantity,
      updated_at: Time.current
    )
  end

  def count_for_lot(lot_id)
    Spree::StockItemLots.joins(:stock_item)
      .where(
        'spree_stock_item_lots.lot_id = ? AND spree_stock_items.stock_location_id = ?',
        lot_id, self.id
      ).first.try(:count) || 0
  end

  private

  def create_stock_items
    inserts = []
    time = Time.now.to_s(:db)
    backorderable = self.backorderable_default?
    Spree::Variant.joins(:product).where('spree_products.vendor_id = ?', self.vendor_id).ids.each do |variant_id|
      inserts.push "(#{self.id}, #{variant_id}, #{backorderable}, '#{time}', '#{time}')"
    end
    if inserts.present?
      sql = "INSERT INTO spree_stock_items (stock_location_id, variant_id, backorderable, created_at, updated_at) VALUES #{inserts.join(', ')};"
      ActiveRecord::Base.connection.execute(sql)
    end
  end

  def update_stock_item_quantity(stock_item, quantity, lot, backorder_fill_qty)
    return unless stock_item.should_track_inventory?
    stock_item.adjust_count_on_hand(quantity, lot, backorder_fill_qty)
  end

  def ensure_one_default
    if self.default
      self.vendor.stock_locations.where(default: true).where.not(id: self.id).update_all(default: false)
    end
  end

  def active_default
    if self.default && !self.active
      self.errors.add(:base, "You cannot deactivate the default location.")
    end
  end


  def state_validate
    # Skip state validation without country (also required)
    # or when disabled by preference
    return if country.blank?
    return unless country.states_required

    # ensure associated state belongs to country
    if state.present?
      if state.country == country
        self.state_name = nil #not required as we have a valid state and country combo
      else
        if state_name.present?
          self.state = nil
        else
          errors.add(:state, :invalid)
        end
      end
    end

    # ensure state_name belongs to country without states, or that it matches a predefined state name/abbr
    if state_name.present?
      if country.states.present?
        states = country.states.find_all_by_name_or_abbr(state_name)

        if states.size == 1
          self.state = states.first
          self.state_name = nil
        else
          errors.add(:state, :invalid)
        end
      end
    end

    # ensure at least one state field is populated
    # errors.add :state, :blank if state.blank? && state_name.blank?
  end

  def postal_code_validate
    return if country.blank? || country.iso.blank?
    return if !TwitterCldr::Shared::PostalCodes.territories.include?(country.iso.downcase.to_sym)

    postal_code = TwitterCldr::Shared::PostalCodes.for_territory(country.iso)
    errors.add(:zipcode, :invalid) if !postal_code.valid?(zipcode.to_s.strip)
  end


end
