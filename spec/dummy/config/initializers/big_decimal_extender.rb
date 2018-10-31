# Overribe bigDecimal to_s
# for 2 when 2.0
class BigDecimal
  alias old_to_s to_s

  def to_s(param = nil)
    old_to_s(param).sub(/(?:(\..*[^0])0+|\.0+)$/, '\1')
  end
end
