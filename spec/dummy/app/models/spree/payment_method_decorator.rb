Spree::PaymentMethod.class_eval do
  include Spree::Integrationable
  has_many :account_payment_methods, class_name: 'Spree::AccountPaymentMethod', foreign_key: :payment_method_id, primary_key: :id
  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id
  has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy
  validate :credit_card_payments_allowed

  scope :active, -> { where(active: true) }
  scope :available_on_front_end, -> { where(active: true, display_on: [:front_end, :both]) }
  scope :available_on_back_end,  -> { where(active: true, display_on: [:back_end, :both]) }
  scope :visible, -> { where.not(display_on: :hidden) }

  attr_default :display_on, 'back_end'

  after_save :ensure_one_mark_paid

  NON_CREDIT_CARD_TYPES = [ "Spree::PaymentMethod::Cash",
                            "Spree::PaymentMethod::Check",
                            "Spree::PaymentMethod::Other" ].freeze

  self.whitelisted_ransackable_attributes = %w{name type description}
  #self.whitelisted_ransackable_associations = %w{tax_category zone}

  def name_for_integration
    "Payment Method: #{self.name}"
  end

  def credit_card?
    true
  end

  Sweet::Application.config.x.payment_methods.each do |pm|
    define_method "to_integration_from_#{pm.to_s.demodulize.underscore}" do |options={}|
      self.send(:to_integration_from_payment_method, options)
    end
  end

  def ensure_one_mark_paid
    if self.mark_paid?
      self.vendor.payment_methods.where(mark_paid: true).where.not(id: self.id).update_all(mark_paid: false)
    end
  end

  private

  def credit_card_payments_allowed
    return true unless vendor
    return true if NON_CREDIT_CARD_TYPES.include?(type)
    return true if vendor.subscription_includes?('payments')

    self.errors.add(:base, 'Credit card payment methods are not supported with your current subscription')
    false
  end


end
