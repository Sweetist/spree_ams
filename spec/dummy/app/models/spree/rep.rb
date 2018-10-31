# == Schema Information
#
# Table name: spree_reps
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  vendor_id  :integer
#

module Spree
  class Rep < Spree::Base
    include Spree::Integrationable
    validates :name, :vendor_id, presence: true
    validates :name, uniqueness: { scope: :vendor_id }
    validates :initials, presence: true, length: { maximum: 5 }
    validates :initials, uniqueness: { scope: :vendor_id }, if: :require_uniq_intials

    belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
    has_many :accounts, class_name: 'Spree::Account', foreign_key: :rep_id, primary_key: :id
    has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy

    default_scope { order(name: :asc) }

    before_destroy :free_accounts

    def free_accounts
      self.accounts.update_all(rep_id: nil)
    end

    private

    def require_uniq_intials
      return false unless vendor
      vendor.has_integration?('qbd')
    end
  end
end
