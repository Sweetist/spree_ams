module Spree
  class StockItemLots < Spree::Base
    belongs_to :lot, class_name: 'Spree::Lot', foreign_key: :lot_id, primary_key: :id
    belongs_to :stock_item, class_name: 'Spree::StockItem', foreign_key: :stock_item_id, primary_key: :id
    has_one :stock_location, through: :stock_item, source: :stock_location
    has_one :variant, through: :stock_item, source: :variant

    scope :sellable, ->(sell_date = Time.current){ joins(:lot).where(
      '(spree_lots.sell_by > ? OR spree_lots.sell_by IS NULL)
      AND (spree_lots.available_at <= ? OR spree_lots.available_at IS NULL)
      AND (spree_lots.expires_at > ? OR spree_lots.expires_at IS NULL)',
      sell_date, sell_date, sell_date) }

    scope :in_stock, -> { where('count > ?', 0)}

    scope :sellable_for, ->(stock_location, sell_date = Time.current) do
      sellable(sell_date)
        .joins(:stock_item)
        .where('spree_stock_items.stock_location_id = ?', stock_location.id)
        .order(id: :desc)
    end

    def can_sell?(sell_date)
      self.count > 0 && lot.can_sell?(sell_date) 
    end
  end
end
