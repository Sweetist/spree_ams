module Spree
  class PaymentMethod::Inner < PaymentMethod::Check
    def credit_card?
      false
    end
  end
end
