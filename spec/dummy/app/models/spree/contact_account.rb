module Spree
  class ContactAccount < Spree::Base
    validates :contact_id, :account_id, presence: true
    validates :contact_id, uniqueness: {scope: :account_id, message: 'already has access to the selected account'}
    belongs_to :contact, class_name: 'Spree::Contact', foreign_key: :contact_id, primary_key: :id
    belongs_to :account, class_name: 'Spree::Account', foreign_key: :account_id, primary_key: :id

    self.whitelisted_ransackable_attributes = %w[account_id contact_id]
    self.whitelisted_ransackable_associations = %w[contact account]
  end
end
