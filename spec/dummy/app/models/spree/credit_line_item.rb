# == Schema Information
#
# Table name: spree_credit_line_items
#
#  id             :integer          not null, primary key
#  line_item_id   :integer
#  credit_memo_id :integer
#  quantity       :decimal(15, 5)   default(0)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#

class Spree::CreditLineItem < Spree::Base
  include Spree::Integrationable
  include Spree::LineItem::Weight
  belongs_to :credit_memo
  has_one :vendor, through: :credit_memo, source: :vendor
  belongs_to :txn_class, class_name: 'Spree::TransactionClass', foreign_key: :txn_class_id, primary_key: :id
  belongs_to :variant
  belongs_to :tax_category

  validates :variant, :item_name, :currency, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, numericality: { greater_than: 0 }

  before_validation :set_currency

  delegate :sku, :pack_size, to: :variant

  self.whitelisted_ransackable_attributes = %w[item_name price quantity]
  self.whitelisted_ransackable_associations = %w[credit_memo variant txn_class]

  def amount
    quantity * price
  end

  private

  def set_currency
    self.currency ||= (credit_memo.try(:currency) || vendor.try(:currency))
  end
end
