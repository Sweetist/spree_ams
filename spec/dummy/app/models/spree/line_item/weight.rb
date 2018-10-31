module Spree::LineItem::Weight
  def weight_in(unit = :oz)
    variant.weight_in(unit) * quantity
  rescue Exception => e
    Rails.logger.error e.message
    0
  end

  def display_weight_in(unit = :oz)
    "#{weight_in(unit)} #{unit}"
  end

  def display_weight
    display_weight_in(variant.wunits).to_s rescue ''
  end
end
