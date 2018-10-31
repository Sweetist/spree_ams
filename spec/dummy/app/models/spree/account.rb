# == Schema Information
#
# Table name: spree_accounts
#
#  id                         :integer          not null, primary key
#  balance                    :decimal(, )      default(0.0), not null
#  status                     :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  number                     :string
#  default_shipping_method_id :integer
#  payment_terms_id           :integer
#  name                       :string
#  active_date                :datetime
#  inactive_date              :datetime
#  inactive_reason            :string
#  rep_id                     :integer
#  customer_type_id           :integer
#  vendor_id                  :integer
#  customer_id                :integer
#  deliverable_days           :json
#  shipping_group_id          :integer
#  fully_qualified_name       :string
#  email                      :string
#  custom_attrs               :jsonb
#
#  parent_id                  :integer
#  display_name               :string


module Spree
  class Account < Spree::Base
    include Spree::Account::Channel::Sweetist
    include Spree::Integrationable
    include Spree::Emailable
    include Spree::Creditable
    include Spree::Balancable
    extend Spree::Account::Export

    validates :vendor_id, presence: true, unless: :skip_vendor_id_verification
    validates :customer_id, presence: true, unless: :skip_customer_id_verification

    validates :name, presence: true
    validate  :uniq_account_number
    validates :name, uniqueness: {scope: [:vendor_id, :parent_id]},:unless => [:skip_name_verification]
    validate  :parent_is_not_self
    validate  :ensure_valid_or_blank_emails
    attr_accessor :skip_customer_id_verification
    attr_accessor :skip_vendor_id_verification
    attr_accessor :skip_name_verification

    belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
    belongs_to :customer, class_name: 'Spree::Company', foreign_key: :customer_id, primary_key: :id
    belongs_to :parent_account, class_name: 'Spree::Account', foreign_key: :parent_id, primary_key: :id
    has_many :sub_accounts, class_name: 'Spree::Account', foreign_key: :parent_id, primary_key: :id

    belongs_to :default_shipping_method, class_name: 'Spree::ShippingMethod', foreign_key: :default_shipping_method_id, primary_key: :id
    belongs_to :payment_terms, class_name: 'Spree::PaymentTerm', foreign_key: :payment_terms_id, primary_key: :id
    belongs_to :rep, class_name: 'Spree::Rep', foreign_key: :rep_id, primary_key: :id
    belongs_to :customer_type, class_name: 'Spree::CustomerType', foreign_key: :customer_type_id, primary_key: :id
    belongs_to :default_stock_location, class_name: 'Spree::StockLocation', foreign_key: :default_stock_location_id, primary_key: :id
    belongs_to :transaction_class, class_name: "Spree::TransactionClass", foreign_key: :default_txn_class_id, primary_key: :id

    has_many :orders, class_name: 'Spree::Order', foreign_key: :account_id, primary_key: :id
    has_many :invoices, class_name: 'Spree::Invoice', foreign_key: :account_id, primary_key: :id
    has_many :standing_orders, class_name: 'Spree::StandingOrder', foreign_key: :account_id, primary_key: :id

    has_many :account_viewable_variants, class_name: 'Spree::AccountViewableVariant',
      foreign_key: :account_id, primary_key: :id, dependent: :destroy
    alias_attribute :avvs, :account_viewable_variants

    has_many :vendor_variants, class_name: 'Spree::VariantVendor',
      foreign_key: :account_id, primary_key: :id, dependent: :destroy
    has_many :purchasable_variants, through: :vendor_variants, source: :variant

    has_many :credit_memos, class_name: 'Spree::CreditMemo',
                            foreign_key: :account_id, primary_key: :id

    has_and_belongs_to_many :promotion_rules,
      class_name: 'Spree::PromotionRule',
      join_table: 'spree_promotion_rules_accounts'
    has_many :promotions, through: :promotion_rules
    has_one :note, class_name: 'Spree::Note', foreign_key: :account_id, primary_key: :id, dependent: :destroy
    belongs_to :shipping_group, class_name: 'Spree::ShippingGroup', foreign_key: :shipping_group_id, primary_key: :id

    accepts_nested_attributes_for :customer
    accepts_nested_attributes_for :note, allow_destroy: true
    accepts_nested_attributes_for :account_viewable_variants

    has_many :shipping_addresses, ->{ where(addr_type: 'shipping') }, class_name: "Spree::Address", foreign_key: :account_id
    belongs_to :default_ship_address, class_name: 'Spree::Address', foreign_key: :default_ship_address_id, primary_key: :id

    has_many :billing_addresses, ->{ where(addr_type: 'billing') }, class_name: "Spree::Address", foreign_key: :account_id, primary_key: :id
    belongs_to :bill_address, class_name: 'Spree::Address', foreign_key: :bill_address_id, primary_key: :id

    alias_attribute :ship_address, :default_ship_address
    alias_attribute :ship_addresses, :shipping_addresses
    alias_attribute :billing_address, :bill_address
    alias_attribute :default_shipping_address, :default_ship_address
    accepts_nested_attributes_for :shipping_addresses
    accepts_nested_attributes_for :billing_addresses

    has_many :contact_accounts, dependent: :destroy, class_name: 'Spree::ContactAccount', foreign_key: :account_id, primary_key: :id
    has_many :contacts, through: :contact_accounts, source: :contact
    belongs_to :primary_cust_contact, class_name: 'Spree::Contact', foreign_key: :primary_cust_contact_id, primary_key: :id
    belongs_to :primary_vendor_contact, class_name: 'Spree::Contact', foreign_key: :primary_vendor_contact_id, primary_key: :id

    belongs_to :tax_category, class_name: 'Spree::TaxCategory', foreign_key: :tax_category_id, primary_key: :id

    has_many :account_price_lists, class_name: 'Spree::PriceListAccount',
      foreign_key: :account_id, primary_key: :id, dependent: :destroy
    has_many :price_lists, through: :account_price_lists, source: :price_list

    delegate :min_lead_days, :after_cutoff?, :time_zone, :currency, to: :vendor

    scope :active, -> { where('spree_accounts.inactive_date IS NULL') }
    scope :inactive, -> { where('spree_accounts.inactive_date IS NOT NULL') }

    after_commit :create_account_viewable_variants, on: :create
    before_save :set_fully_qualified_name
    before_save :set_default_display_name
    after_save :update_sub_account_fully_qualified_names, if: :fully_qualified_name_changed?

    before_create :init_default_stock_location

    acts_as_commontable

    self.whitelisted_ransackable_attributes = %w[
      number balance external_balance available_credit external_credit status
      inactive_date created_at fully_qualified_name default_display_name
      display_name customer_type_id rep_id parent_id email
      last_invoice_date last_ordered_at
    ]
    self.whitelisted_ransackable_associations = %w[customer vendor user customer_type]

    has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy
    has_many :integration_actions, as: :integrationable, class_name: 'Spree::IntegrationAction'

    has_paper_trail class_name: 'Spree::Version'

    after_commit :notify_integration
    before_create :activate_account
    before_save :set_deliverable_days

    has_many :user_accounts, dependent: :destroy, class_name: 'Spree::UserAccount', foreign_key: :account_id, primary_key: :id
    has_many :users, through: :user_accounts, source: :user

    has_many :payments, through: :orders
    has_many :account_payment_methods, class_name: 'Spree::AccountPaymentMethod', foreign_key: :account_id, primary_key: :id
    has_many :payment_methods, through: :account_payment_methods, source: :payment_method
    has_many :credit_cards, class_name: 'Spree::CreditCard', foreign_key: :account_id, primary_key: :id

    attr_accessor :synchronous_avv_create

    attr_default :deliverable_days do
    {
      "0" => true,
      "1" => true,
      "2" => true,
      "3" => true,
      "4" => true,
      "5" => true,
      "6" => true
    }
    end

    attr_default :custom_attrs do
      {}
    end

    attr_default :send_mail, 'account_contacts'

    # problem with commontator and prepend
    def thread
      @thread ||= super
      return @thread unless @thread.nil?

      @thread = build_thread
      @thread.save if persisted?
      @thread
    end

    def init_default_stock_location
      self.default_stock_location ||= vendor.try(:stock_locations).try(:first)
    end

    def create_default_stock_location
      return if default_stock_location.present?
      return unless vendor
      sl = vendor.stock_locations.first
      sl ||= Spree::StockLocation.create!( vendor: vendor,
                                           name: 'Default',
                                           backorderable_default: true )
      self.default_stock_location = sl
      save!
    end

    def self.mail_to_settings
      [
        ['Account & Contacts', 'account_contacts'],
        ['Account Only', 'account'],
        ['Contacts Only', 'contacts'],
        ['None', 'none']
      ]
    end

    def self.view_editable_attributes
      #should return array of attributes
      [:balance]
    end

    def self.restricted_view_editable_attributes
      [:balance]
    end

    def self.display_send_mail(setting)
      Spree::Account.mail_to_settings.to_h.key(setting).to_s rescue ''
    end

    def self.valid_mail_to_setting?(setting)
      Spree::Account.display_send_mail(setting).present?
    end

    def orders_including_sub_accounts
      Spree::Order.where(account_id: [self.id] + [self.sub_account_ids])
    end

    def display_send_mail
      Spree::Account.display_send_mail(self.send_mail).to_s rescue ''
    end

    def display_name_and_number
      name = default_display_name || ''
      name += " (Acct ##{number})" unless number.blank?

      name
    end

    def account_balance(use_external = nil)
      use_external = use_external.nil? ? vendor.use_external_balance : use_external
      use_external ? external_balance : balance
    end

    def display_account_balance(use_external = nil)
      Spree::Money.new(account_balance(use_external), currency: self.currency)
    end

    def should_show_balance?
      return false unless vendor.show_account_balance?
      !!vendor.try(:cva).try(:account_balance)
    end
    def should_see_balance?
      should_show_balance?
    end
    def should_see_spend?
      !!vendor.try(:cva).try(:account_spend)
    end
    def should_see_past_due_balance?
      return false unless vendor.show_account_balance?
      !!vendor.try(:cva).try(:account_past_due_balance)
    end

    def is_tax_exempt?
      !self.taxable
    end

    def payment_due_before_submit?
      self.payment_terms.try(:pay_before_submit) && self.vendor.try(:payment_methods).present?
    end

    def vendor_has_payment_methods?
      self.vendor.payment_methods.active.exists?
    end

    def payment_days
      self.payment_terms.try(:num_days).to_i
    end

    def notify_integration
      #add delay to allow for match.no_sync to be set
      Sidekiq::Client.push(
        'class' => AccountSync,
        'at' => Time.current.to_i + 2.seconds,
        'queue' => 'integrations',
        'args' => [self.id]
      ) if Spree::IntegrationItem.where(account_sync: true, vendor_id: [self.vendor_id, self.customer_id]).any?
    end

    def can_sync?(integration_item)
      !!sync_for_item(integration_item).fetch(:result, true) rescue true
    end

    def name_for_integration
      "#{self.fully_qualified_name}"
    end

    def promotion_ids
      self.account_viewable_variants.pluck(:promotion_ids).flatten.uniq
    end

    def create_account_viewable_variants
      if self.synchronous_avv_create
        avv_ids = []
        vendor.variants_including_master.find_each do |variant|
          avv = avvs.find_or_create_by(variant_id: variant.id)
          avv.find_eligible_promotions
          avv.cache_price(avv.eligible_promotions.unadvertised)
        end
      else
        Sidekiq::Client.push('class' => AccountCreateAvvWorker, 'queue' => 'critical', 'args' => [self.id, self.vendor_id])
      end
    end

    def inactive?
      self.inactive_date.present?
    end

    def active?
      self.inactive_date.blank?
    end

    def activate_account
      active_date = Time.current
    end

    def activate!
      self.update_columns(
        active_date: Time.current,
        inactive_date: nil,
        inactive_reason: nil
      )
    end

    def deactivate!
      if self.sub_accounts.active.any?
        self.errors[:base] << "Cannot make account with active sub-accounts inactive"
        false
      else
        self.update_columns(
          inactive_date: Time.current,
          active_date: nil
        )
        true
      end
    end

    def replace_or_remove_primary_contact(contact_id)
      other_contacts = self.contacts.where.not(id: contact_id).order('created_at ASC') # get array of contacts with exception of passed in id
      new_contact_id = other_contacts.try(:first).try(:id) # get oldest contact's id
      self.update_columns(primary_cust_contact_id: new_contact_id) # set new primary as oldest id (or nil)

      new_contact_id
    end

    def delivery_on_sunday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(self.deliverable_days["0"])
    end

    def delivery_on_monday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(self.deliverable_days["1"])
    end

    def delivery_on_tuesday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(self.deliverable_days["2"])
    end

    def delivery_on_wednesday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(self.deliverable_days["3"])
    end

    def delivery_on_thursday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(self.deliverable_days["4"])
    end

    def delivery_on_friday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(self.deliverable_days["5"])
    end

    def delivery_on_saturday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(self.deliverable_days["6"])
    end

    def delivery_on_sunday=(value)
      self.deliverable_days ||= {}
      self.deliverable_days["0"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def delivery_on_monday=(value)
      self.deliverable_days ||= {}
      self.deliverable_days["1"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def delivery_on_tuesday=(value)
      self.deliverable_days ||= {}
      self.deliverable_days["2"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def delivery_on_wednesday=(value)
      self.deliverable_days ||= {}
      self.deliverable_days["3"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def delivery_on_thursday=(value)
      self.deliverable_days ||= {}
      self.deliverable_days["4"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def delivery_on_friday=(value)
      self.deliverable_days ||= {}
      self.deliverable_days["5"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def delivery_on_saturday=(value)
      self.deliverable_days ||= {}
      self.deliverable_days["6"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def set_deliverable_days
      if self.shipping_group_id
        self.deliverable_days = self.shipping_group.deliverable_days
      end
    end

    def set_fully_qualified_name
      if self.parent_account
        self.fully_qualified_name = "#{self.parent_account.fully_qualified_name}:#{self.name}"
      else
        self.fully_qualified_name = "#{self.name}"
      end

      self.fully_qualified_name
    end

    def update_sub_account_fully_qualified_names
      self.sub_accounts.each do |a|
        a.update(fully_qualified_name: a.set_fully_qualified_name)
      end
    end

    def set_default_display_name
      self.default_display_name = self.display_name.present? ? self.display_name : self.fully_qualified_name
      self.default_display_name
    end

    def multiple_accounts?
      if self.persisted?
        self.customer.present? && self.customer.vendor_accounts.where('vendor_id = ? AND id != ?', self.vendor_id, self.id).count >= 1
      else
        self.customer.present? && self.customer.vendor_accounts.where('vendor_id = ? AND id IS NOT NULL', self.vendor_id).count > 0
      end
    end

    def can_select_delivery?
      !!self.vendor.selectable_delivery
    end

    def vendor_account_name
      if self.name.present?
        "#{self.vendor.try(:name)} - #{self.default_display_name}"
      else
        "#{self.vendor.try(:name)}"
      end
    end

    def order_date_text
      self.vendor.order_date_text.to_s.capitalize
    end

    def available_shipping_methods
      self.vendor.shipping_methods.select{|sm| sm.include?(self.default_ship_address)}
    end

    def collect_customer_emails(options = {})
      customer_emails = []
      case self.send_mail
      when 'account_contacts'
        customer_emails += self.contacts.map do |recipient|
          next if recipient.email.blank?
          recipient.valid_emails unless recipient.user.try(:is_admin?)
        end.flatten.compact
        customer_emails += self.valid_emails(options[:email_type])
      when 'account'
        customer_emails += self.valid_emails(options[:email_type])
      when 'contacts'
        customer_emails += self.contacts.map do |recipient|
          next if recipient.email.blank?
          recipient.valid_emails unless recipient.user.try(:is_admin?)
        end.flatten.compact
      end

      if customer_emails.empty? && options[:override_account_email_settings]
        customer_emails += self.valid_emails(options[:email_type])
      end

      customer_emails.uniq
    end

    def customer_emails_string
      collect_customer_emails.join(', ')
    end

    def next_available_delivery_date(time = Time.current)
      vendor.next_available_delivery_date(self, time)
    end

    def default_country
      shipping_addresses.includes(:country).map{|addr| addr.country }.compact.first ||
      billing_addresses.includes(:country).map{|addr| addr.country }.compact.first ||
      customer.ship_address.try(:country) ||
      customer.bill_address.try(:country) ||
      vendor.bill_address.try(:country) ||
      vendor.ship_address.try(:country) ||
      Spree::Country.where(iso: Sweet::Application.config.x.default_country_iso).first
    end

    def default_country_iso
      default_country.try(:iso)
    end

    def set_bill_address(address_id)
      update_columns(bill_address_id: address_id) if address_id
    end

    def set_default_ship_address(address_id)
      update_columns(default_ship_address_id: address_id) if address_id
    end

    def family_ids
      self.vendor.customer_accounts.where(customer_id: customer_id).ids
    end

    def thirty_day_spend
      orders.where('delivery_date BETWEEN ? AND ?', Time.current.to_date - 30.days, Time.current.to_date)
            .approved
            .sum(:total)
    end

    def past_due_balance(channels = [])
      due_orders = past_due_orders
      due_orders = due_orders.where(channel: channels) if channels.present?
      due_orders.select("sum(total - payment_total) as amount_due").map(&:amount_due).first
    end

    def past_due_orders
      orders.where('due_date < ?', Time.current.in_time_zone(vendor.time_zone).to_date - payment_terms.try(:num_days).to_i.days)
                         .where(state: ApprovedStates)
                         .where(payment_state: 'balance_due')
    end

    def past_due?
      return false if balance <= 0
      past_due_orders.present?
    end

    def set_catalog_visibility_from_price_lists
      variant_ids = price_lists.map do |pl|
        next unless pl.active?
        pl.price_list_variants.map(&:variant_id)
      end.flatten.compact.uniq

      if variant_ids.empty?
        avvs.joins(:variant)
            .where('spree_variants.visible_to_all = ?', false)
            .update_all(visible: false)
      else
        avvs.where(variant_id: variant_ids).update_all(visible: true)
        avvs.joins(:variant)
            .where('spree_variants.visible_to_all = ?', false)
            .where.not(variant_id: variant_ids).update_all(visible: false)
      end
    end

    def set_last_order_dates
      order_dates = {}
      order_dates[:last_ordered_at] = orders.where(state: InvoiceableStates).maximum(:completed_at)
      order_dates[:last_invoice_date] = orders.where(state: InvoiceableStates).maximum(:invoice_date)
      update_columns(order_dates)
    end

    private

    def parent_is_not_self
      if self.parent_id.blank? || self.parent_id != self.id
        true
      else
        self.errors[:base] << "Account cannot be parent of itself"
        false
      end
    end

    def uniq_account_number
      return true if number.blank?
      return true unless self.vendor
      valid = true
        if id.nil?
          valid = self.vendor.customer_accounts
                             .where.not(customer_id: customer_id)
                             .where(number: number).empty?
        else
          valid = self.vendor.customer_accounts
                             .where.not(id: id, customer_id: customer_id)
                             .where(number: number).empty?
        end

      unless valid
        self.errors.add(:number, 'is already taken')
      end
      valid
    end

    def ensure_valid_or_blank_emails
      ensure_all_valid_or_blank_emails && ensure_all_valid_or_blank_emails(:shipment)
    end

  end
end
