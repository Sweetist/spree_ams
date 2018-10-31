module Spree::Order::Weight
  def weight_in(unit = :oz)
    variants.inject(0) { |sum, v| sum + v.weight_in(unit) }
  end

  def total_weight_in(unit = :oz)
    line_items.inject(0) { |sum, li| sum + li.weight_in(unit) }
  end

  def display_total_weight_in(unit = :lb)
    "#{total_weight_in(unit)} #{unit}" rescue ''
  end
end
