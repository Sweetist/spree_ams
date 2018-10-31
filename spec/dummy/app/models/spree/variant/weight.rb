module Spree::Variant::Weight
  def weight_in(unit = :oz)
    weight = Measurement.parse(display_weight)
    weight.convert_to(unit).quantity #quantity is the numeric portion of the weight
  rescue
    Rails.logger.error 'Error in weight converison'
    0
  end

  def display_weight
    "#{weight} #{wunits}".strip
  end

  def display_weight_in(unit = :oz)
    "#{weight_in(unit)} #{unit}"
  end

  def wunits
    return weight_units if weight_units.present?
    vendor.try(:weight_units)
  end
end
