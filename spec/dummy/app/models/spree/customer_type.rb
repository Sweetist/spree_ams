# == Schema Information
#
# Table name: spree_customer_types
#
#  id        :integer          not null, primary key
#  name      :string           not null
#  vendor_id :integer
#

module Spree
  class CustomerType < Spree::Base
    include Spree::Integrationable

    validates :name, presence: true
    validates :name, uniqueness: { scope: :vendor_id }

    belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
    has_many :accounts, class_name: 'Spree::Account', foreign_key: :customer_type_id, primary_key: :id
    has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy
    has_many :price_lists, class_name: 'Spree::PriceList', foreign_key: :customer_type_id, primary_key: :id
    default_scope { order(name: :asc) }

    before_destroy :free_accounts

    self.whitelisted_ransackable_attributes = %w[name]

    def free_accounts
      self.accounts.update_all(customer_type_id: nil)
    end
  end
end
