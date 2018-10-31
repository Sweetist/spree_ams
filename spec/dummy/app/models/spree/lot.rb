module Spree
  class Lot < Spree::Base
    belongs_to :variant
    belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
    has_many :inventory_units, class_name: 'Spree::InventoryUnit', foreign_key: :lot_id, primary_key: :id
    has_many :line_item_lots, class_name: 'Spree::LineItemLots',
      foreign_key: :lot_id, primary_key: :id, dependent: :destroy
    has_many :line_items, through: :line_item_lots

    has_many :stock_item_lots, class_name: 'Spree::StockItemLots',
      foreign_key: :lot_id, primary_key: :id, dependent: :destroy
    has_many :stock_items, through: :stock_item_lots, source: :stock_item
    has_many :stock_locations, through: :stock_items

    has_many :stock_movements, class_name: 'Spree::StockMovement', foreign_key: :lot_id, primary_key: :id

    has_many :part_lots, class_name: 'Spree::PartLot',
      foreign_key: :assembly_lot_id, primary_key: :id, dependent: :destroy
    has_many :assembly_lots, class_name: 'Spree::PartLot',
      foreign_key: :part_lot_id, primary_key: :id, dependent: :destroy

    validates :variant_id, :number, presence: true

    scope :stockable, -> { where('(sell_by > ? AND qty_on_hand > ?) OR (qty_on_hand = ? AND qty_sold = ?)', Time.current, 0, 0, 0) }
    scope :sellable, -> (sell_date = Time.current){ where(
      '(sell_by >= ? OR sell_by IS NULL)
      AND (available_at <= ? OR available_at IS NULL)
      AND (expires_at >= ? OR expires_at IS NULL)',
      sell_date, sell_date, sell_date) }
    scope :unsellable_for_date, -> (sell_date = Time.current){ where(
      '(sell_by IS NOT NULL AND sell_by < ?)
      OR (available_at IS NOT NULL AND available_at > ?)
      OR (expires_at IS NOT NULL AND expires_at < ?)',
      sell_date, sell_date, sell_date) }

    scope :in_stock, -> { where('qty_on_hand > ?', 0) }
    scope :expired, -> (sell_date = Time.current){ where('expires_at IS NOT NULL AND expires_at < ?', sell_date) }
    scope :unexpired, -> (sell_date = Time.current){ where('expires_at IS NULL OR expires_at >= ?', sell_date) }
    scope :archived, -> { where('archived_at IS NOT NULL') }
    scope :unarchived, -> { where('archived_at IS NULL') }
    scope :uninitialized, -> { where(qty_on_hand: 0, qty_sold: 0, qty_waste: 0) }

    self.whitelisted_ransackable_attributes = %w[number created_at expires_at sell_by available_at qty_on_hand variant_id archived_at]
    self.whitelisted_ransackable_associations = %w[variant part_lots]

    def available
      qty_on_hand > 0 && (sell_by.blank? || sell_by > Time.current) && (expires_at.blank? || expires_at > Time.current)
    end

    def display_with_expiray(options = {})
      spacer = options[:spacer] || '&nbsp;&nbsp;&nbsp;'
      date = options[:date] || Time.current
      options[:with_date] = true if options[:with_date].nil?

      lot_text = number
      if expired?(date)
        lot_text += "#{spacer}(expired)"
      elsif options[:with_date]
        exp = DateHelper.display_vendor_date_format(expires_at, vendor.date_format)
        lot_text += "#{spacer}exp. #{exp}" if exp.present?
      end

      lot_text
    end

    def expired?(date = Time.current)
      return false if expires_at.nil?
      expires_at < date
    end

    def uninitialized?
      qty_on_hand.zero? && qty_sold.zero?
    end

    def add_stock?
      uninitialized? || available
    end

    def count_at_stock_item(stock_item_id)
      Spree::StockItemLots.where(lot_id: self.id, stock_item_id: stock_item_id).first.try(:count) || 0
    end

    def count_at_stock_location(stock_location_id)
      location_item_lot = stock_item_lots.detect do |item_lot|
        item_lot.stock_item.try(:stock_location_id) == stock_location_id
      end

      return 0 unless location_item_lot
      location_item_lot.count
    end

    def archived?
      archive
    end
    def archive
      archived_at.present?
    end
    def archive=(value)
      if value.to_bool
        self.archived_at = Time.current
      else
        self.archived_at = nil
      end
    end

    def move_qty(qty, stock_item_lot)
      stock_item_lot.count += qty
      stock_item_lot.save!
      self.qty_on_hand += qty
      save!
    end

    def sell_or_restock_items(qty, stock_location_id)
      new_qty = self.qty_on_hand - qty.to_f
      new_sold = self.qty_sold + qty.to_f
      self.update_columns(qty_on_hand: new_qty, qty_sold: new_sold)
      stock_item = Spree::StockItem.where(variant: self.variant, stock_location_id: stock_location_id).first
      stock_item_lot = self.stock_item_lots.where(stock_item: stock_item).first
      if stock_item_lot
        new_stock_item_lot_count = stock_item_lot.count - qty.to_f
        stock_item_lot.update_columns(count: new_stock_item_lot_count)
      end
    end

    def can_sell?(sell_date)
      return false if available_at && available_at > sell_date
      return false if sell_by && sell_by < sell_date
      return false if expires_at && expires_at < sell_date

      true
    end

  end
end
