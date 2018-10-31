Spree::Calculator::PriceSack.class_eval do

  def compute(object)
    if object.is_a?(Array)
      base = object.map { |o| o.respond_to?(:amount) ? o.amount : BigDecimal(o.to_s) }.sum
    else
      base = object.respond_to?(:amount) ? object.amount : BigDecimal(object.to_s)
    end

    if base < self.preferred_minimal_amount.to_d
      self.preferred_normal_amount.to_d
    else
      self.preferred_discount_amount.to_d
    end
  end
end
