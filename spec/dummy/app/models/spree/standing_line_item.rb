# == Schema Information
#
# Table name: spree_standing_line_items
#
#  id                :integer          not null, primary key
#  variant_id        :integer
#  standing_order_id :integer
#  quantity          :integer
#  price             :decimal(, )
#  currency          :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#

module Spree
  class StandingLineItem < Spree::Base
    after_destroy :recalculate_dates

    belongs_to :variant, class_name: 'Spree::Variant', foreign_key: :variant_id, primary_key: :id
    belongs_to :standing_order, class_name: 'Spree::StandingOrder', foreign_key: :standing_order_id, primary_key: :id
    belongs_to :transaction_class, class_name: "Spree::TransactionClass", foreign_key: :txn_class_id, primary_key: :id


    before_create :set_pack_size

    validates :variant, presence: true
    validates :quantity, numericality: { greater_than_or_equal_to: 0 }
    validate :step_size

    self.whitelisted_ransackable_associations = %w[customer vendor variant]
    self.whitelisted_ransackable_attributes = %w[name frequency_id start_at next_at pack_size position]

    def recalculate_dates
      self.standing_order.recalculate_dates
    end

    def self.with_avv
      joins(:standing_order, variant: :account_viewable_variants)
      .where('spree_account_viewable_variants.account_id = ?, spree_account_viewable_variants.variant_id = ?')
    end

    def total
      avv = Spree::AccountViewableVariant
            .where(variant_id: variant.id,
                   account_id: standing_order.account_id).first

      return variant.price * quantity unless avv.present?
      avv.price * quantity
    end

    private

    def set_pack_size
      self.pack_size = self.variant.try(:pack_size).to_s if self.pack_size.blank?
    end

    def step_size
      return true if self.quantity % variant.step_size == 0
      errors.add(:base, "Must order #{variant.flat_or_nested_name} in multiples of #{variant.step_size}")
      false
    end
  end
end
