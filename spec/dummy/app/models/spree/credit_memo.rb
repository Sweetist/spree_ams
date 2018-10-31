# == Schema Information
#
# Table name: spree_credit_memos
#
#  id                   :integer          not null, primary key
#  vendor_id            :integer
#  account_id           :integer
#  number               :string
#  total                :decimal(15, 5)   default(0)
#  item_total           :decimal(15, 5)   default(0)
#  additional_tax_total :decimal(15, 5)   default(0)
#  included_tax_total   :decimal(15, 5)   default(0)
#  shipment_total       :decimal(15, 5)   default(0)
#  amount_remaining     :decimal(15, 5)   default(0)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#

class Spree::CreditMemo < Spree::Base
  extend FriendlyId
  friendly_id :number, slug_column: :number, use: :slugged
  include Spree::NumberGenerator
  include Spree::Integrationable
  include Spree::Order::Weight

  CREDIT_MEMO_NUMBER_LENGTH = 9
  DEFAULT_CREDIT_MEMO_PREFIX = 'R'

  belongs_to :vendor, class_name: 'Spree::Company',
                      foreign_key: :vendor_id, primary_key: :id
  belongs_to :account, class_name: 'Spree::Account',
                       foreign_key: :account_id, primary_key: :id
  has_one :customer, through: :account, source: :customer
  has_many :credit_line_items, dependent: :destroy
  alias_method :line_items, :credit_line_items
  has_many :applied_credits
  has_many :account_payments, through: :applied_credits
  belongs_to :txn_class, class_name: 'Spree::TransactionClass',
                         foreign_key: :txn_class_id, primary_key: :id
  belongs_to :shipping_method, class_name: 'Spree::ShippingMethod',
                               foreign_key: :shipping_method_id,
                               primary_key: :id
  belongs_to :stock_location, class_name: 'Spree::StockLocation',
                              foreign_key: :stock_location_id, primary_key: :id
  has_many :integration_sync_matches, as: :integration_syncable,
                                      class_name: 'Spree::IntegrationSyncMatch',
                                      dependent: :destroy
  has_many :integration_actions, as: :integrationable,
                                 class_name: 'Spree::IntegrationAction'

  validates :vendor, :account, :number, :txn_date, presence: true
  validates :number, uniqueness: true
  validates :total,
            :item_total,
            :additional_tax_total,
            :included_tax_total,
            :shipment_total,
            :amount_remaining, numericality: { greater_than_or_equal_to: 0 }

  after_initialize :set_txn_date
  before_validation :fill_defaults, :persist_totals

  after_create :move_account_credit_amount

  accepts_nested_attributes_for :credit_line_items, allow_destroy: true

  self.whitelisted_ransackable_attributes = %w[number total account_id vendor_id created_at updated_at]
  self.whitelisted_ransackable_associations = %w[vendor account account_payments shipping_method]

  def move_account_credit_amount
    account.move_credit_amount(total, self)
  end

  def fill_defaults
    self.currency ||= vendor.currency || 'USD'
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
      options[:prefix] += vendor.credit_memo_prefix.nil? ? "#{DEFAULT_CREDIT_MEMO_PREFIX}" : "#{vendor.credit_memo_prefix}"
    end
    self.number = nil if options[:renumber]
    if vendor.try(:use_sequential_credit_memo_number?)
      next_number = vendor.credit_memo_next_number.to_s
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

        break unless Spree::CreditMemo.exists?(number: self.number)
      end

      vendor.credit_memo_next_number = next_number
      vendor.update_columns(invoice_settings: vendor.invoice_settings)
    else
      # Always hiding first letter so use 'RR'
      options[:prefix] ||= "#{prefix_scope}#{DEFAULT_CREDIT_MEMO_PREFIX}"
      options[:length] ||= CREDIT_MEMO_NUMBER_LENGTH
      super
    end

    self.number
  end

  def display_number
    start = prefix_scope.length
    number.to_s.slice(start..-1)
  end

  def display_with_creation_date
    "Credit Memo #{display_number}"
  end

  def prefix_scope
    "#{DEFAULT_CREDIT_MEMO_PREFIX}#{vendor_id}-"
  end

  def self.number_from_integration(num, vendor_id)
    "#{DEFAULT_CREDIT_MEMO_PREFIX}#{vendor_id}-#{num}"
  end

  def quantity
    line_items.sum(:quantity)
  end

  def find_credit_line_item_by_variant(variant, options = {})
    credit_line_items.detect { |credit_line_item| credit_line_item.variant_id == variant.id }
  end

  def add_many(variants, options = {})
    options[:nest_name] = vendor.try(:cva).try(:variant_nest_name)
    vendor.variants_including_master.where(id: variants.keys).each do |variant|
      credit_line_item = add_to_credit_line_item(
        variant,
        variants.fetch(variant.id.to_s, {}).fetch(:quantity, 1),
        variants.fetch(variant.id.to_s, {}).fetch(:price, variant.price),
        options
      )
    end
    self.save!
  end

  def remove(variant, quantity = 1, options = {})
    credit_line_item = remove_from_credit_line_item(variant, quantity, options)
  end

  def add_to_credit_line_item(variant, quantity, price, options = {})
    item_name = options[:nest_name] ? variant.full_display_name : variant.default_display_name
    # credit_line_item = self.credit_line_items.new(quantity: quantity, variant: variant, price: price, position: variant.position)
    credit_line_item = self.credit_line_items.new(
      variant: variant,
      quantity: quantity,
      price: price,
      item_name: item_name
    )

    credit_line_item.txn_class_id = variant.try(:txn_class_id) if variant.vendor.track_line_item_class?

    credit_line_item
  end

  def remove_from_credit_line_item(variant, quantity, options = {})
    credit_line_item = grab_credit_line_item_by_variant(variant, true, options)
    credit_line_item.quantity -= quantity

    if credit_line_item.quantity.zero?
      self.credit_line_items.destroy(credit_line_item)
    else
      credit_line_item.save!
    end

    credit_line_item
  end

  def grab_credit_line_item_by_variant(variant, raise_error = false, options = {})
    credit_line_item = self.find_credit_line_item_by_variant(variant, options)

    if !credit_line_item.present? && raise_error
      raise ActiveRecord::RecordNotFound, "Line item not found for variant #{variant.sku}"
    end

    credit_line_item
  end

  def persist_totals
    return if id.nil?
    self.item_total = line_amounts_sum
    self.update_columns(
      total: total_credit,
      amount_remaining: amount_remaining_with_applied_credits,
      item_total: self.item_total
    )
  end

  def total_credit
    [
      item_total,
      additional_tax_total,
      included_tax_total,
      shipment_total
    ].sum
  end

  def line_amounts_sum
    sum = 0
    credit_line_items.each do |item|
      sum += (item.quantity * item.price)
    end
    sum
  end

  def amount_remaining_with_applied_credits
    total_credit - applied_credits.sum(:amount)
  end

  def notify_integration
    if Spree::IntegrationItem.where(vendor_id: self.vendor_id).any?
      Sidekiq::Client.push(
        'at' => Time.current.to_i + 2.seconds,
        'class' => CreditMemoSync,
        'queue' => 'integrations',
        'args' => [self.id]
      )
    end
  end

  def name_for_integration
    "Credit Memo: #{self.display_number} for: #{self.account.try(:fully_qualified_name)}"
  end

  private

  def set_txn_date
    self.txn_date ||= DateHelper.sweet_today(vendor.try(:time_zone) || 'UTC')
  end
end
