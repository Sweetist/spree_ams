Spree::CreditCard.class_eval do
  include ActiveMerchant::Billing::CreditCardMethods
  belongs_to :account, class_name: 'Spree::Account', foreign_key: :account_id, primary_key: :id
  scope :active, -> { where('spree_credit_cards.deleted_at IS NULL') }
  scope :deleted, -> { where('spree_credit_cards.deleted_at IS NOT NULL') }
  
  attr_accessor :zip, :manual_entry

  def display_expiry
    "Exp #{0 if self.month < 10}#{self.month}/#{self.year.to_s[-2..-1]}"
  end
end
