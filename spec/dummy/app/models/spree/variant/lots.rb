module Spree::Variant::Lots
  # return sellable stock item lots for stock location to cover quantity
  def sellable_lots_for_location_and_qty(stock_location, qty, sell_date = Time.current)
    sils = stock_item_lots.sellable_for(stock_location, sell_date)
    return nil if sils.sum(:count) < qty

    result = []
    sils.each do |sil|
      internal_result = {}
      fill_qty = (qty >= sil.count ? sil.count : qty)
      qty -= sil.count
      internal_result[:lot_id] = sil.lot.id
      internal_result[:quantity] = fill_qty
      result << internal_result
      return result if qty <= 0
    end
  end

  def lot_trackable?
    INVENTORY_TYPES.key?(variant_type)
  end

  def avialiable_lots_for_location_and_qty(stock_location, qty, sell_date = Time.current)
    sils = sellable_lots_for_location_and_qty(stock_location, qty, sell_date)
    sils.map(&:lot)
  end

  def should_track_lots?
    can_track_lots? && lot_tracking
  end

  def can_track_lots?
    return false unless vendor.try(:lot_tracking)
    return false unless vendor.subscription_includes?('lot_tracking')
    lot_trackable?
  end
end
