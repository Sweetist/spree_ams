Measurement.class_eval do
  Measurement.define(:g) do |unit|
    unit.alias :gram, :grams, :gm
    unit.convert_to(:t) { |value| value / 1_000_000.0 }
    unit.convert_to(:kg) { |value| value / 1_000.0 }
    unit.convert_to(:hg) { |value| value / 100.0 }
    unit.convert_to(:dag) { |value| value / 10.0 }
    unit.convert_to(:dg) { |value| value * 10.0 }
    unit.convert_to(:cg) { |value| value * 100.0 }
    unit.convert_to(:mg) { |value| value * 1_000.0 }
    unit.convert_to(:oz) { |value| value * 0.035274 }
    unit.convert_to(:lb) { |value| value * 0.00220462 }
  end

  Measurement.define(:kg) do |unit|
    unit.alias :kilogram, :kilograms, :kgs
    unit.convert_to(:t) { |value| value / 1_000.0 }
    unit.convert_to(:hg) { |value| value * 10.0 }
    unit.convert_to(:dag) { |value| value * 100.0 }
    unit.convert_to(:g) { |value| value * 1_000.0 }
    unit.convert_to(:dg) { |value| value * 10_000.0 }
    unit.convert_to(:cg) { |value| value * 100_000.0 }
    unit.convert_to(:mg) { |value| value * 1_000_000.0 }
    unit.convert_to(:oz) { |value| value * 35.274 }
    unit.convert_to(:lb) { |value| value * 2.20462 }
  end

  Measurement.define(:lb) do |unit|
    unit.alias :lbs, :pound, :pounds
    unit.convert_to(:ton) { |value| value / 2000.0 }
    unit.convert_to(:cwt) { |value| value / 100.0 }
    unit.convert_to(:oz) { |value| value * 16.0 }
    unit.convert_to(:dr) { |value| value * 256.0 }
    unit.convert_to(:gr) { |value| value * 7_000.0 }
    unit.convert_to(:kg) { |value| value * 0.453592 }
    unit.convert_to(:g) { |value| value * 453.592 }
  end

  Measurement.define(:oz) do |unit|
    unit.alias :ounce, :ounces
    unit.convert_to(:ton) { |value| value / 32_000.0 }
    unit.convert_to(:cwt) { |value| value / 1_600.0 }
    unit.convert_to(:lb) { |value| value / 16.0 }
    unit.convert_to(:dr) { |value| value * 16.0 }
    unit.convert_to(:gr) { |value| value * 437.5 }
    unit.convert_to(:kg) { |value| value * 0.0283495 }
    unit.convert_to(:g) { |value| value * 28.3495 }
  end
end
