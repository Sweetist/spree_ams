Spree::Payment.class_eval do
  include Spree::Integrationable

  belongs_to :account_payment
  has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy
  has_paper_trail class_name: 'Spree::Version', unless: Proc.new { |payment| payment.id.nil? }
  has_one :account, through: :order

  attr_accessor :payment_date

  state_machine do
    after_transition to: :completed do |payment|
      payment.notify_integration
    end
    after_transition to: :void do |payment|
      payment.notify_integration
    end
  end


  def name_for_integration
    invoice = self.order.try(:invoice)
    if invoice && invoice.number != self.order.display_number
      "Payment(#{self.number}) for Order #{self.order.display_number} / Invoice #{invoice.number}(#{self.order.try(:account).try(:fully_qualified_name)})"
    else
      "Payment(#{self.number}) for Order: #{self.order.display_number}(#{self.order.try(:account).try(:fully_qualified_name)})"
    end
  end

  def display_number
    account_payment.try(:display_number) || number
  end

  def notify_integration
    return unless self.order
    return if self.account_payment.present?
    if Spree::IntegrationItem.where(vendor_id: self.order.vendor_id, order_sync: true).any?
      Sidekiq::Client.push(
        'at' => Time.current.to_i + 2.seconds,
        'class' => PaymentSync,
        'queue' => 'integrations',
        'args' => [self.id]
      )
    end
  end

  def transaction_id
    txn_id.present? ? txn_id : response_code
  end

  def display_transaction_id
    account_payment.try(:transaction_id) || transaction_id
  end

  def update_order
    if completed? || void?
      order.updater.update_payment_total
    end

    if order.completed?
      order.updater.update_payment_state
      order.updater.update_shipments
      order.updater.update_shipment_state
      order.updater.update_invoice
    end

    if self.completed? || order.completed?
      order.persist_totals
    end
  end

  def amount_after_refund
    amount ? amount - refunds.sum(:amount) : amount
  end

  def editable_on_order_page?
    return true unless account_payment
    return true if account_payment.orders.count == 1 &&
                   account_payment.orders.first.total == account_payment.amount
    false
  end

  def handle_payment_preconditions
    unless block_given?
      raise ArgumentError, 'handle_payment_preconditions must be called with a block'
    end

    if payment_method && payment_method.source_required?
      if source
        unless processing?
          if payment_method.supports?(source) || token_based?
            yield
          else
            invalidate!
            raise Spree::Core::GatewayError, Spree.t(:payment_method_not_supported)
          end
        end
      else
        raise Spree::Core::GatewayError, Spree.t(:payment_processing_failed)
      end
    elsif payment_method
      yield
    end
  end

end
