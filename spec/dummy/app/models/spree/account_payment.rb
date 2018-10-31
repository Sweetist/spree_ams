class Spree::AccountPayment < Spree::Base
  include Spree::Integrationable
  extend FriendlyId
  friendly_id :number, slug_column: :number, use: :slugged
  include Spree::Payment::Processing
  include Spree::NumberGenerator

  ACCOUNT_PAYMENT_NUMBER_LENGTH = 7
  DEFAULT_ACCOUNT_PAYMENT_PREFIX = 'P'

  has_many :credit_transactions, as: :originator,
                                 class_name: 'Spree::CreditTransaction',
                                 dependent: :destroy

  has_many :balance_transactions, as: :originator,
                                  class_name: 'Spree::BalanceTransaction',
                                  dependent: :destroy

  NON_RISKY_AVS_CODES = %w[B D H J M Q T V X Y].freeze
  RISKY_AVS_CODES     = %w[A C E F G I K L N O P R S U W Z].freeze

  has_many :payments, dependent: :destroy
  accepts_nested_attributes_for :payments
  has_many :orders, -> { where('spree_payments.state <> ? AND spree_payments.state <> ?', 'void', 'invalid') },
           through: :payments
  has_many :void_orders, -> { where('spree_payments.state = ?', 'void') },
           through: :payments, foreign_key: :order_id, source: :order
  has_many :refunds
  has_many :applied_credits
  has_many :credit_memos, through: :applied_credits

  belongs_to :source, polymorphic: true
  belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
  belongs_to :vendor, class_name: 'Spree::Company',
                      foreign_key: :vendor_id, primary_key: :id
  belongs_to :account, class_name: 'Spree::Account',
                       foreign_key: :account_id, primary_key: :id
  has_one :customer, class_name: 'Spree::Company',
                     through: :account, source: :customer

  has_many :offsets, -> { offset_payment }, class_name: 'Spree::Payment',
                                            foreign_key: :source_id
  has_many :log_entries, as: :source
  has_many :state_changes, as: :stateful
  has_many :capture_events, class_name: 'Spree::PaymentCaptureEvent'
  has_many :integration_actions, as: :integrationable, class_name: 'Spree::IntegrationAction'
  has_many :integration_sync_matches, as: :integration_syncable,
                                      class_name: 'Spree::IntegrationSyncMatch',
                                      dependent: :destroy

  has_paper_trail class_name: 'Spree::Version',
                  unless: proc { |account_payment| account_payment.id.nil? }

  scope :with_state, ->(s) { where(state: s.to_s) }

  scope :checkout, -> { with_state('checkout') }
  scope :completed, -> { with_state('completed') }
  scope :pending, -> { with_state('pending') }
  scope :processing, -> { with_state('processing') }
  scope :failed, -> { with_state('failed') }
  scope :valid, -> { where.not(state: Spree::Payment::INVALID_STATES) }

  validates :vendor, :account, :customer, presence: true

  validates_numericality_of :amount, greater_than: 0

  before_validation :validate_source
  before_save :ensure_currency

  after_initialize :build_source
  after_create :ensure_payment_date

  after_save :create_payment_profile, if: :profiles_supported?

  attr_accessor :source_attributes, :request_env, :refund_reason_id,
                :edit_with_capture, :orders_amount_sum

  self.whitelisted_ransackable_attributes = %w[number state amount txn_id credit_amount credit_to_apply account_id vendor_id created_at updated_at]
  self.whitelisted_ransackable_associations = %w[customer vendor account]

  state_machine initial: :checkout do
    # With card payments, happens before purchase or authorization happens
    #
    # Setting it after creating a profile and authorizing a full amount will
    # prevent the payment from being authorized again once Order transitions
    # to complete
    event :started_processing do
      transition from: %i[checkout pending completed processing], to: :processing
    end
    # When processing during checkout fails
    event :failure do
      transition from: %i[pending processing], to: :failed
    end
    # With card payments this represents authorizing the payment
    event :pend do
      transition from: %i[checkout processing], to: :pending
    end
    # With card payments this represents completing a purchase or capture transaction
    event :complete do
      transition from: %i[processing pending checkout], to: :completed
    end
    event :void do
      transition from: %i[pending processing completed checkout], to: :void
    end
    # when the card brand isnt supported
    event :invalidate do
      transition from: [:checkout], to: :invalid
    end
    before_transition to: :completed do |account_payment|
      account_payment.pend! unless account_payment.amount_and_credit_valid?
    end

    after_transition to: :completed do |account_payment|
      account_payment.update_credit_amount_and_account_credit_and_balance
      account_payment.notify_integration
    end

    after_transition to: :void do |account_payment|
      account_payment.void_child_payments!
      account_payment
        .account
        .move_balance_amount(account_payment.amount, account_payment)
      account_payment.notify_integration
    end

    after_transition do |account_payment, transition|
      account_payment.state_changes.create!(
        previous_state: transition.from,
        next_state:     transition.to,
        name:           'account_payment'
      )
    end
  end

  def generate_number(options = {})
    return self.number if self.number && self.number.start_with?(prefix_scope) && !options[:renumber]

    if self.number && !self.number.start_with?(prefix_scope) && !options[:renumber]
      prev_num = self.number.split('-')[1..-1].join('-')
      if prev_num.present?
        self.number = "#{prefix_scope}#{prev_num}"
        return self.number
      end
    end

    if vendor
      options[:prefix] = prefix_scope
      options[:prefix] += vendor.account_payment_prefix.nil? ? "#{DEFAULT_ACCOUNT_PAYMENT_PREFIX}" : "#{vendor.account_payment_prefix}"
    end
    self.number = nil if options[:renumber]
    if vendor.try(:use_sequential_account_payment_number?)
      next_number = vendor.account_payment_next_number.to_s
      loop do
        self.number = "#{options[:prefix].to_s.strip}#{next_number}"
        # get original number length with padding
        len = next_number.length
        # increase numerical value
        next_number = next_number.to_i + 1
        # get length of numerical value
        len2 = next_number.to_s.length
        # get the number of zeros for padding after the number increases
        # need this for when number length increases Ex. 0009999 + 1 = 0010000
        pad_length = [len - len2, 0].max
        # reassemble next_number
        next_number = "#{'0' * pad_length}#{next_number}"

        break unless Spree::AccountPayment.exists?(number: self.number)
      end

      vendor.account_payment_next_number = next_number
      vendor.update_columns(invoice_settings: vendor.invoice_settings)
    else
      # Always hiding first letter so use 'PP'
      options[:letters] = true
      options[:prefix] ||= "#{prefix_scope}#{DEFAULT_ACCOUNT_PAYMENT_PREFIX}"
      options[:length] ||= ACCOUNT_PAYMENT_NUMBER_LENGTH
      super
    end

    self.number
  end

  def display_number
    start = prefix_scope.length
    number.to_s.slice(start..-1)
  end

  def prefix_scope
    "#{DEFAULT_ACCOUNT_PAYMENT_PREFIX}#{vendor_id}-"
  end

  def self.number_from_integration(num, vendor_id)
    "#{DEFAULT_ACCOUNT_PAYMENT_PREFIX}#{vendor_id}-#{num}"
  end

  def remove_credit_memos!
    applied_credits.destroy_all
  end

  def applied_credit_memo?(credit_memo)
    credit_memos.pluck(:id).include? credit_memo.id
  end

  def applied_credit_amount_for(credit_memo)
    applied_credit = applied_credits.find_by(credit_memo: credit_memo)
    return 0 unless applied_credit
    applied_credit.amount
  end

  def add_credit_memos(credit_memos_data)
    ActiveRecord::Base.transaction do
      credit_memos_data.each do |data|
        applied_credits.create!(credit_memo_id: data['credit_memo_id'],
                                amount: data['amount'])
      end
    end
  end

  def add_and_process_child_payments(payments_data)
    ActiveRecord::Base.transaction do
      payments_data.each do |data|
        add_payment(data['order_id'], data['amount'])
      end
      process_child_payments! if payment_method.auto_capture?
    end
  end

  def add_payment(order_id, amount)
    inner_method = Spree::AccountPayment.inner_payment_method
    payments.create!(order_id: order_id,
                     amount: amount.to_d,
                     channel: channel,
                     payment_method: inner_method)
  end

  def notify_integration
    if Spree::IntegrationItem.where(vendor_id: self.vendor_id, order_sync: true).any?
      Sidekiq::Client.push(
        'at' => Time.current.to_i + 2.seconds,
        'class' => AccountPaymentSync,
        'queue' => 'integrations',
        'args' => [self.id]
      )
    end
  end

  def name_for_integration
    "Payment(#{self.display_number}) for Account #{self.account.fully_qualified_name}"
  end

  def credit_card?
    payment_method.try(:credit_card?)
  end

  def editable?
    return false unless SWEET_SALES_CHANNELS.include?(channel)
    return false if %w[void failed invalid].include?(state)
    # NOTE update is not working for completed cash/check payments,
    # so not allowing them to be updated for now. Change the condtion to only
    # check completed credit card payments when fixed
    return false if completed? && credit_card?
    # return false if completed?

    true
  end

  def show_payment_detail?
    %w[pending completed void].include?(state) && \
      payment_method.try(:credit_card?)
  end

  def amount_and_credit_valid?
    return true if credit_amount_valid? && \
                   amount_valid? && \
                   available_credit_valid?
    void_child_payments!
    false
  end

  def available_credit_valid?
    return true if credit_to_apply <= account.available_credit

    account_credit_less_than_zero
  end

  def amount_valid?
    return true if amount + credit_to_apply - orders_amount_to_pay >= 0

    errors.add :amount, Spree.t('errors.not_enough_amount')
    false
  end

  def credit_amount_valid?
    return credit_to_apply_less_than_zero_error if credit_to_apply < 0
    return true if credit_to_apply.zero?
    return credit_is_unused_error if orders_amount_to_pay > 0 && \
                                     amount - orders_amount_to_pay >= 0
    true
  end

  def orders_amount_to_pay
    return orders_amount_sum if orders_amount_sum.present?

    raise 'Not added orders_amount_sum to Account Payment'
  end

  def credit_is_unused_error
    errors.add :applying_a_credit, Spree.t('errors.unused_credit')
    false
  end

  def account_credit_less_than_zero
    errors.add :available_credit, Spree.t('errors.less_than_zero')
    false
  end

  def credit_to_apply_less_than_zero_error
    errors.add :credit, Spree.t('errors.less_than_zero')
    false
  end

  def cannot_edit_error
    errors.add :base, Spree.t(:cannot_edit_error, scope: :errors,
                                                  object_class: 'payment')
  end

  def process_and_capture
    return unless amount_and_credit_valid?
    process!
    return unless payment_method.auto_capture?
    capture!
  end

  def pend_child_payments!
    payments.checkout.each(&:pend!)
    payments.processing.each(&:pend!)
  end

  def process_child_payments!
    payments.checkout.each(&:process!)
  end

  def void_child_payments!
    payments.each(&:void_transaction!)
  end

  # default payment method
  def offsets_total
    offsets.sum(:amount)
  end

  def credit_allowed
    amount - (offsets_total.abs + refunds.sum(:amount))
  end

  def can_credit?
    credit_allowed > 0
  end

  def captured_amount
    capture_events.sum(:amount)
  end

  def uncaptured_amount
    amount - captured_amount
  end

  def current_credit_amount
    amount - orders_amount_sum + credit_to_apply
  end

  def last_credit_transaction_amount
    return 0 unless credit_transactions.where(use_credit: true).any?

    credit_transactions.where(use_credit: true).last.amount
  end

  def amount_was_from_transaction
    return 0 unless balance_transactions.any?

    balance_transactions.last.amount
  end

  def update_credit_on_change_credit_to_apply
    return if credit_to_apply == last_credit_transaction_amount

    previous_credit = last_credit_transaction_amount
    account.reload.move_credit_amount(previous_credit, self, true)
    account.reload.move_credit_amount(-credit_to_apply, self, true)

    account.reload.move_balance_amount(-previous_credit, self)
    account.reload.move_balance_amount(credit_to_apply, self)
  end

  def update_credit_on_change_credit_amount
    return if credit_amount == current_credit_amount

    account.reload.move_credit_amount(-credit_amount, self)
    account.reload.move_credit_amount(current_credit_amount, self)

    update_columns(credit_amount: current_credit_amount)
  end

  def update_balance_on_update_amount
    provious_amount = -amount_was_from_transaction
    return if provious_amount == amount

    account.reload.move_balance_amount(provious_amount, self)
    account.reload.move_balance_amount(-amount, self)
  end

  def update_credit_amount_and_account_credit_and_balance
    return unless amount_and_credit_valid?

    update_credit_on_change_credit_to_apply
    update_credit_on_change_credit_amount
    update_balance_on_update_amount
  end

  def money
    Spree::Money.new(amount, currency: currency)
  end

  alias display_amount money

  def gateway_options
    Spree::AccountPayment::GatewayOptions.new(self).to_hash
  end

  def self.inner_payment_method
    Spree::PaymentMethod.where(name: 'inner')
                        .first_or_create do |method|
                          method.auto_capture = true
                          method.type = 'Spree::PaymentMethod::Inner'
                        end
  end

  def amount=(amount)
    self[:amount] =
      case amount
      when String
        separator = I18n.t('number.currency.format.separator')
        number    = amount.delete("^0-9-#{separator}\.").tr(separator, '.')
        number.to_d if number.present?
      end || amount
  end

  def build_source
    return unless new_record?
    if source_attributes.present? && source.blank? && payment_method.try(:payment_source_class)
      self.source = payment_method.payment_source_class.new(source_attributes)
      self.source.payment_method_id = payment_method.id
    end
  end

  def actions
    return [] unless payment_source && (payment_source.respond_to? :actions)
    payment_source.actions.select { |action| !payment_source.respond_to?("can_#{action}?") or payment_source.send("can_#{action}?", self) }
  end

  def transaction_id
    txn_id.present? ? txn_id : response_code
  end

  def display_transaction_id
    transaction_id
  end

  def payment_source
    res = source.is_a?(Spree::AccountPayment) ? source.source : source
    res || payment_method
  end

  def create_refund(refund_params)
    refund_reason = Spree::RefundReason.find(refund_params[:refund_reason_id])
    transaction do
      refund_params[:payments_attributes].each do |payment|
        amt = payment[:amount].to_d
        next if amt.zero?
        p = Spree::Order.find(payment[:order_id]).payments.where(
          account_payment_id: id
        ).last
        p.refunds.create!(reason: refund_reason,
                          amount: amt)
      end
      refunds.create!(reason: refund_reason, amount: refund_params[:amount])
    end
  rescue ActiveRecord::RecordInvalid => e
    raise Spree::Core::GatewayError.new(e)
  end

  def capture!(amount = nil)
    return true if completed?
    process_child_payments! unless payment_method.auto_capture?
    amount ||= display_amount.money.cents
    started_processing!
    protect_from_connection_error do
      # Standard ActiveMerchant capture usage
      response = payment_method.capture(
        amount,
        response_code,
        gateway_options
      )
      amount_for_capture = ::Money.new(amount, currency)
      capture_events.create!(amount: amount_for_capture.to_f)
      split_uncaptured_amount
      handle_response(response, :complete, :failure)
    end
  end

  def amount_after_refund
    amount ? amount - refunds.sum(:amount) : amount
  end

  def orders_for_edit
    if void?
      void_orders.distinct
    else
      orders.all
    end
  end

  private

  def ensure_payment_date
    return unless payment_date.nil?
    date = Time.current.in_time_zone(vendor.time_zone).to_date
    update_columns(payment_date: date)
  rescue
    update_columns(payment_date: Time.current.to_date)
  end

  def ensure_currency
    self.currency ||= vendor.try(:currency)
  end

  def split_uncaptured_amount; end

  def validate_source
    if source && !source.valid?
      source.errors.each do |field, error|
        field_name = I18n.t("activerecord.attributes.#{source.class.to_s.underscore}.#{field}")
        self.errors.add(Spree.t(source.class.to_s.demodulize.underscore), "#{field_name} #{error}")
      end
    end
    return !errors.present?
  end

  def profiles_supported?
    payment_method.respond_to?(:payment_profiles_supported?) &&
      payment_method.payment_profiles_supported?
  end

  def create_payment_profile
    # Don't attempt to create on bad payments.
    return if %w[invalid failed].include?(state)
    # Payment profile cannot be created without source
    return unless source
    # Imported payments shouldn't create a payment profile.
    return if source.imported

    payment_method.create_profile(self)
  rescue ActiveMerchant::ConnectionError => e
    gateway_error e
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
