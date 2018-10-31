Spree::Refund.class_eval do
  include Spree::Integrationable
  has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy

  before_validation :erase_validations

  has_one :order, through: :payment, source: :order
  belongs_to :account_payment
  validates :account_payment, presence: true
  validate :amount_is_less_than_or_equal_to_allowed_amount, on: :create

  after_save :notify_integration
  after_save :move_account_balance

  def move_account_balance
    return unless account_payment

    account_payment.account.move_balance_amount(amount - amount_was, self)
  end

  def linked_payment
    account_payment || payment.try(:account_payment) || payment
  end

  def name_for_integration
    invoice = order.try(:invoice)
    if invoice && invoice.number != self.payment.order.try(:display_number)
      "Refund(#{self.payment.display_number}) for Order #{order.try(:display_number)} / Invoice #{invoice.number}(#{order.try(:account).try(:fully_qualified_name)})"
    else
      "Refund(#{self.payment.display_number}) for Order: #{order.display_number}(#{order.try(:account).try(:fully_qualified_name)})"
    end
  end

  def notify_integration

    if self.account_payment.present?
      if Spree::IntegrationItem.where(vendor_id: self.account_payment.vendor_id, order_sync: true).any?
        Sidekiq::Client.push(
          'at' => Time.current.to_i + 2.seconds,
          'class' => AccountPaymentSync,
          'queue' => 'integrations',
          'args' => [self.account_payment_id]
        )
      end
    elsif self.order.present?
      if self.reimbursement.nil? #refund with no return
        if Spree::IntegrationItem.where(vendor_id: self.order.vendor_id, order_sync: true).any?
          Sidekiq::Client.push(
            'at' => Time.current.to_i + 2.seconds,
            'class' => PaymentSync,
            'queue' => 'integrations',
            'args' => [self.payment_id]
          )
        end
      else
        #TODO sync reimbursement/return items
      end
    end
  end

  def perform!
    payment = self.payment || account_payment
    return true if transaction_id.present?

    credit_cents = Spree::Money.new(amount.to_f, currency: payment.currency)
                               .money.cents

    @response = process!(credit_cents)

    self.transaction_id = @response.authorization
    update_columns(transaction_id: transaction_id)
    update_order
  end

  # return an activemerchant response object if successful or else raise an error
  def process!(credit_cents)
    payment = self.payment || account_payment
    response = if payment.payment_method.payment_profiles_supported?
                 credit_with_source(payment, credit_cents)
               else
                 credit_without_source(payment, credit_cents)
               end
    unless response.success?
      logger.error(Spree.t(:gateway_error) + "  #{response.to_yaml}")
      text = response.params['message'] ||
             response.params['response_reason_text'] || response.message
      raise Spree::Core::GatewayError.new(text)
    end

    response
  rescue ActiveMerchant::ConnectionError => e
    logger.error(Spree.t(:gateway_error) + "  #{e.inspect}")
    raise Spree::Core::GatewayError.new(Spree.t(:unable_to_connect_to_gateway))
  end

  def amount_is_less_than_or_equal_to_allowed_amount
    payment = self.payment || account_payment
    errors.add(:amount, :greater_than_allowed) if
      amount > payment.credit_allowed
  end

  def update_order
    payment = self.payment || account_payment
    return unless payment.respond_to?(:order)
    payment.order.updater.update
  end

  def erase_validations
    if account_payment.present?
      _validators[:payment].first.attributes.delete(:payment)
    else
      _validators[:account_payment].first.attributes.delete(:account_payment)
    end
  end

  def credit_with_source(payment, credit_cents)
    payment.payment_method.credit(credit_cents,
                                  payment.source,
                                  payment.transaction_id,
                                  originator: self)
  end

  def credit_without_source(payment, credit_cents)
    payment.payment_method.credit(credit_cents,
                                  payment.transaction_id,
                                  originator: self)
  end
end
