# Extend NilClass with methods
class NilClass
  def to_d
    BigDecimal.new(0)
  end
end
