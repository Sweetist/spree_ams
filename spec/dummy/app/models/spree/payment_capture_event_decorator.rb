Spree::PaymentCaptureEvent.class_eval do
  belongs_to :account_payment, class_name: 'Spree::AccountPayment'

  def display_amount
    payment = self.payment || account_payment

    Spree::Money.new(amount, currency: payment.currency)
  end
end
