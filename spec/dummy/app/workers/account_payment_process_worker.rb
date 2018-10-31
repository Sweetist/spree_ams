class AccountPaymentProcessWorker
  include Sidekiq::Worker

  def perform(account_payment_id, payments_data)
    account_payment = Spree::AccountPayment.find_by(id: account_payment_id)
    return unless account_payment

    account_payment.add_and_process_child_payments(payments_data)
  end
end
