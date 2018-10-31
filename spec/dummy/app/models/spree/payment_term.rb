# == Schema Information
#
# Table name: spree_payment_terms
#
#  id          :integer          not null, primary key
#  name        :string           not null
#  description :text
#  num_days    :integer          default(0)
#

module Spree
  class PaymentTerm < Spree::Base
    include Spree::Integrationable
    validates :name, presence: true, uniqueness: true
    has_many :accounts, class_name: 'Spree::Account', foreign_key: :payment_terms_id, primary_key: :id
    has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy

    def name_with_required
      if self.pay_before_submit?
        "#{self.name} - pay on order submit"
      else
        "#{self.name}"
      end
    end

    def name_with_required_short
      if self.pay_before_submit?
        "#{self.name} **"
      else
        "#{self.name}"
      end
    end
  end
end
