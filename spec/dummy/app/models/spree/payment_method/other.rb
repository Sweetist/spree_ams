module Spree
  class PaymentMethod::Other < PaymentMethod::Check

    def credit_card?
      false
    end
  end
end
