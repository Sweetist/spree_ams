module Spree
  class PaymentMethod::Cash < PaymentMethod::Check

    def credit_card?
      false
    end
  end
end
