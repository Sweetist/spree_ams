Spree::PaymentMethod::Check.class_eval do
  def credit_card?
    false
  end

  def authorize(*)
    simulated_successful_billing_response
  end

  def purchase(*)
    simulated_successful_billing_response
  end
end
