
# == Schema Information
#
# Table name: spree_companies
#
#  id                      :integer          not null, primary key
#  name                    :string           not null
#  order_cutoff_time       :string
#  delivery_minimum        :decimal(, )      default(0.0)
#  slug                    :string
#  email                   :string
#  time_zone               :string
#  theme_colors            :json
#  theme_name              :string
#  theme_css               :text
#  settings                :json
#  invoice_settings        :json
#  daily_summary_send_at   :datetime
#  bill_address_id         :integer
#  ship_address_id         :integer
#  custom_domain           :string           default(""), not null
#  access_level            :integer          default(0), not null
#  internal_company_number :string
#  tax_exempt_id           :string
#  created_at              :datetime
#  updated_at              :datetime
#

module Spree
  class Company < Spree::Base
    include Spree::Integrationable
    include Spree::Emailable
    include Spree::Company::Settings
    include Spree::Company::InvoiceSettings
    include Spree::Company::Carriers
    include Spree::Company::SampleData
    include Spree::Company::Resets
    SWEET_CHANNEL = 'sweet'.freeze
    B2B_PORTAL_CHANNEL = 'b2b'.freeze

    validates :name, :time_zone, :order_cutoff_time, presence: true
    validates :custom_domain, uniqueness: true, if: 'custom_domain.present?'
    validate :ensure_all_valid_or_blank_emails
    validate :next_numbers_presence
    validate :included_in_subscription
    # validates :email, uniqueness: true, allow_blank: true
    has_many :users, class_name: 'Spree::User', foreign_key: :company_id, primary_key: :id
    accepts_nested_attributes_for :users
    has_many :spree_roles, through: :users, foreign_key: :company_id
    belongs_to :ship_address, foreign_key: :ship_address_id, class_name: 'Spree::Address'
    accepts_nested_attributes_for :ship_address
    belongs_to :bill_address, class_name: 'Spree::Address', foreign_key: :bill_address_id
    accepts_nested_attributes_for :bill_address
    alias_attribute :shipping_address, :ship_address
    after_create :set_up_tax_categories
    after_create :set_up_default_permisssion_groups
    after_create :set_up_customer_viewable_attribute
    after_create :set_up_order_rules
    after_save :adjust_subscription_accessibles, if: :subscription_changed?

    has_many :credit_memos, class_name: 'Spree::CreditMemo',
                            foreign_key: :vendor_id, primary_key: :id
    has_many :transaction_classes, class_name: "Spree::TransactionClass", foreign_key: :vendor_id, primary_key: :id
    alias_attribute :txn_classes, :transaction_classes
    ##### Vendor Associations ###############################
    has_many :forms, class_name: 'Spree::Form', foreign_key: :vendor_id, primary_key: :id
    has_many :account_payments, class_name: 'Spree::AccountPayment', foreign_key: :vendor_id, primary_key: :id
    has_many :products, class_name: 'Spree::Product', foreign_key: :vendor_id, primary_key: :id
    accepts_nested_attributes_for :products
    has_many :variants, through: :products
    has_many :variants_including_master, through: :products, source: :variants_including_master
    has_many :product_imports, class_name: 'Spree::ProductImport', foreign_key: :vendor_id, primary_key: :id
    has_many :stock_locations, class_name: 'Spree::StockLocation', foreign_key: :vendor_id, primary_key: :id
    has_one :default_stock_location, -> { where(default: true) }, class_name: 'Spree::StockLocation', foreign_key: :vendor_id, primary_key: :id
    has_many :stock_items, through: :stock_locations, source: :stock_items
    has_many :stock_transfers, class_name: 'Spree::StockTransfer', foreign_key: :company_id, primary_key: :id
    has_many :lots, class_name: 'Spree::Lot', foreign_key: :vendor_id, primary_key: :id
    has_many :line_item_lots, through: :lots, source: :line_item_lots
    has_many :stock_item_lots, through: :stock_items, source: :stock_item_lots
    has_many :lots_stock_locations, -> { distinct }, through: :stock_item_lots, source: :stock_location

    has_many :sales_orders, class_name: 'Spree::Order', foreign_key: :vendor_id, primary_key: :id
    accepts_nested_attributes_for :sales_orders
    has_many :sales_line_items, through: :sales_orders, source: :line_items
    has_many :sales_invoices, class_name: 'Spree::Invoice', foreign_key: :vendor_id, primary_key: :id
    accepts_nested_attributes_for :sales_invoices
    has_many :sales_invoice_line_items, through: :sales_invoices
    has_many :sales_standing_orders, class_name: 'Spree::StandingOrder', foreign_key: :vendor_id, primary_key: :id
    has_many :sales_standing_order_schedules, through: :sales_standing_orders, source: :standing_order_schedules

    has_many :zones, class_name: 'Spree::Zone', foreign_key: :vendor_id, primary_key: :id
    has_many :shipping_categories, class_name: 'Spree::ShippingCategory', foreign_key: :vendor_id, primary_key: :id
    has_many :shipping_methods, -> { distinct }, through: :shipping_categories
    has_many :sales_shipments, through: :sales_orders, source: :shipments

    has_many :customer_accounts, class_name: 'Spree::Account', foreign_key: :vendor_id, primary_key: :id
    has_many :parent_customer_accounts, -> {where(parent_id: nil)},
              class_name: 'Spree::Account', foreign_key: :vendor_id, primary_key: :id
    has_many :customers, through: :customer_accounts, foreign_key: :vendor_id
    has_many :active_customer_accounts, -> { active }, class_name: 'Spree::Account', foreign_key: :vendor_id, primary_key: :id
    has_many :active_customers, through: :active_customer_accounts, source: :customer
    has_many :customer_notes, through: :customer_accounts
    has_many :customer_imports, class_name: 'Spree::CustomerImport', foreign_key: :vendor_id, primary_key: :id

    has_many :vendor_imports, class_name: 'Spree::VendorImport', foreign_key: :company_id, primary_key: :id

    has_many :account_viewable_products, through: :products
    has_many :account_viewable_variants, through: :customer_accounts, source: :account_viewable_variants
    alias_attribute :avvs, :account_viewable_variants

    has_many :order_rules, class_name: 'Spree::OrderRule', foreign_key: :vendor_id, primary_key: :id, dependent: :destroy
    has_many :promotions, class_name: 'Spree::Promotion', foreign_key: :vendor_id, primary_key: :id
    has_many :promotion_categories, class_name: "Spree::PromotionCategory", foreign_key: :vendor_id, primary_key: :id
    has_many :price_lists, class_name: 'Spree::PriceList', foreign_key: :vendor_id, primary_key: :id
    has_many :taxonomies, class_name: 'Spree::Taxonomy', foreign_key: :vendor_id, primary_key: :id
    has_many :taxons, class_name: 'Spree::Taxon', foreign_key: :vendor_id, primary_key: :id
    has_many :option_values, class_name: 'Spree::OptionValue', foreign_key: :vendor_id, primary_key: :id
    has_many :option_types, class_name: 'Spree::OptionType', foreign_key: :vendor_id, primary_key: :id
    has_one  :customer_viewable_attribute, class_name: 'Spree::CustomerViewableAttribute', foreign_key: :vendor_id, primary_key: :id, dependent: :destroy
    alias_attribute :cva, :customer_viewable_attribute
    has_many :images, -> { order(:position) }, as: :viewable, dependent: :destroy, class_name: "Spree::CompanyImage"
    has_many :logos, -> { order(:position) }, as: :viewable, dependent: :destroy, class_name: "Spree::CompanyLogo"
    has_many :banner_images, -> { order(:position) }, as: :viewable, dependent: :destroy, class_name: "Spree::BannerImage"
    has_one  :banner_image, through: :customer_viewable_attribute, source: :banner_image

    has_many :integration_items, class_name: 'Spree::IntegrationItem', foreign_key: :vendor_id, primary_key: :id
    has_many :sales_integration_items, -> {where(integration_type: :sales_channel)},
                class_name: 'Spree::IntegrationItem', foreign_key: :vendor_id, primary_key: :id
    has_many :accounting_integration_items, -> {where(integration_type: :accounting)},
                class_name: 'Spree::IntegrationItem', foreign_key: :vendor_id, primary_key: :id
    has_many :shipping_integration_items, -> {where(integration_type: :shipping)},
                class_name: 'Spree::IntegrationItem', foreign_key: :vendor_id, primary_key: :id
    has_many :integration_item_actions, through: :integration_items, source: :integration_actions
    has_many :chart_accounts, class_name: 'Spree::ChartAccount', foreign_key: :vendor_id, primary_key: :id
    has_many :reps, class_name: 'Spree::Rep', foreign_key: :vendor_id, primary_key: :id
    has_many :customer_types, class_name: 'Spree::CustomerType', foreign_key: :vendor_id, primary_key: :id

    has_one :default_shipping_group, -> { where is_default: true }, class_name: 'Spree::ShippingGroup', foreign_key: :vendor_id, primary_key: :id
    has_many :shipping_groups, class_name: 'Spree::ShippingGroup', foreign_key: :vendor_id, primary_key: :id, dependent: :destroy
    has_many :tax_categories, class_name: 'Spree::TaxCategory', foreign_key: :vendor_id, primary_key: :id
    has_many :tax_rates, class_name: 'Spree::TaxRate', through: :tax_categories

    #######################################################
    has_many :vendor_accounts, class_name: 'Spree::Account', foreign_key: :customer_id, primary_key: :id
    has_many :vendors, through: :vendor_accounts, foreign_key: :customer_id
    has_many :vendor_notes, through: :vendor_accounts
    has_many :purchase_orders, through: :vendor_accounts, source: :orders
    has_many :purchase_line_items, through: :purchase_orders, source: :line_items
    has_many :purchase_standing_orders, class_name: 'Spree::StandingOrder', foreign_key: :customer_id, primary_key: :id
    has_many :purchase_standing_order_schedules, through: :purchase_standing_orders, source: :standing_order_schedules
    has_many :purchase_invoices, through: :vendor_accounts, source: :invoices
    has_many :payment_methods, class_name: 'Spree::PaymentMethod', foreign_key: :vendor_id, primary_key: :id

    has_many :purchase_shipments, through: :purchase_orders

    has_paper_trail class_name: 'Spree::Version'

    accepts_nested_attributes_for :ship_address
    accepts_nested_attributes_for :customer_accounts, allow_destroy: true
    accepts_nested_attributes_for :sales_orders
    accepts_nested_attributes_for :sales_invoices
    accepts_nested_attributes_for :customer_viewable_attribute
    accepts_nested_attributes_for :lots

    validates_associated :ship_address
    validates_associated :bill_address
    self.whitelisted_ransackable_attributes = %w[name email]
    self.whitelisted_ransackable_associations = %w[ship_address bill_address taxons products users]

    has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy
    has_many :integration_actions, as: :integrationable, class_name: 'Spree::IntegrationAction'

    after_update :update_account_names, if: :name_changed?

    has_one :default_permission_group, -> { where is_default: true }, class_name: 'Spree::PermissionGroup', foreign_key: :vendor_id, primary_key: :id
    has_many :permission_groups, class_name: 'Spree::PermissionGroup', foreign_key: :company_id, primary_key: :id

    has_many :contacts, class_name: 'Spree::Contact', foreign_key: :company_id, primary_key: :id
    has_many :pages, class_name: 'Spree::Page', foreign_key: :company_id, primary_key: :id

    has_many :payment_methods, class_name: 'Spree::PaymentMethod', foreign_key: :vendor_id, primary_key: :id
    has_many :sales_payments, through: :sales_orders, source: :payments
    has_many :purchase_payments, through: :purchase_orders, source: :payments
    # has_many :master_credit_cards

    has_many :vendor_payment_methods, through: :vendor_accounts, source: :payment_methods
    has_many :customer_account_payment_method, through: :customer_accounts, source: :account_payment_methods

    has_many :email_templates, class_name: 'Spree::EmailTemplate', foreign_key: :vendor_id, primary_key: :id

    # this needs to search ids first because DISTINCT does not work on classes that have attributes
    # with type :json
    # TODO migrate type :json to :jsonb and refactor
    def self.vendor_companies
      Spree::Company.where(id: Spree::Company.joins(:spree_roles).where('spree_roles.name = ?', 'vendor').ids.uniq)
    end

    #######################################################

    #TODO decide whether or not to implement setup_vendor_taxonomy on after create
    # after_create :setup_vendor_taxonomy

    Subscription = {'sweetist' => 0, 'starter' => 1, 'plus' => 2, 'plus_lot_tracking' => 3, 'platinum' => 4, 'enterprise' => 5}

    attr_default :order_cutoff_time, '11:59 PM'
    attr_default :theme_name, 'light2'
    attr_default :subscription, 'starter'
    attr_accessor :header_background_color
    attr_accessor :header_text_color
    attr_accessor :sidebar_background_color
    attr_accessor :sidebar_text_color

    attr_default :theme_colors do
      { 'header_background' => nil, 'header_text' => nil, 'sidebar_background' => nil, 'sidebar_text' => nil }
    end

    def domain
      return custom_domain if custom_domain.present?
      ENV['DEFAULT_URL_HOST']
    end

    def sales_channels
      channel = integration_items.with_integration_type(:sales_channel)
                                 .try(:pluck, :integration_key) \
                + [B2B_PORTAL_CHANNEL, SWEET_CHANNEL]
      channel.map { |c| [Spree.t(c), c] }
    end

    def set_up_order_rules
      Spree::OrderRule.create_moq_rule_if_not_exist(self)
    end

    def self.available_themes
      ["blue", "darkblue", "default", "grey", "light", "light2", "custom"]
    end

    def all_accounts
      Spree::Account.where('customer_id = ? OR vendor_id = ?', self.id, self.id)
    end

    def request_account_form
      forms.request_access.active.first
    end

    def showable_variants
      products_with_variants_ids = self.products.joins(:variants).distinct.ids
      unless products_with_variants_ids.empty?
        return self.variants_including_master.where(
          '(is_master = ? and product_id in (?)) or (is_master = ? and product_id not in (?))',
          false, products_with_variants_ids, true, products_with_variants_ids
        )
      end
      self.variants_including_master
    end

    def to_vendor_date(date)
      # Should only be used for datetimes. DO NOT use for dates from datepickers
      # that are store as a datetime with timestamp 00:00:00 UTC. This may give the
      # wrong result
      DateHelper.to_vendor_date_format(date.in_time_zone(time_zone), date_format)
    end

    def today_orders
      orders_between Time.current.in_time_zone(self.time_zone).beginning_of_day.to_date, Time.current.in_time_zone(self.time_zone).to_date
    end

    def weekly_orders
      orders_between 6.days.ago.in_time_zone(self.time_zone).to_date, Time.current.in_time_zone(self.time_zone).to_date
    end

    def month_to_date_orders_count
      orders_count_between(
        Time.current.beginning_of_month.in_time_zone(self.time_zone).to_date,
        Time.current.in_time_zone(self.time_zone).to_date,
        ApprovedStates
      )
    end

    def monthly_orders
      orders_between 29.days.ago.in_time_zone(self.time_zone).to_date, Time.current.in_time_zone(self.time_zone).to_date
    end

    def monthly_orders_count
      orders_count_between 29.days.ago.in_time_zone(self.time_zone).to_date, Time.current.in_time_zone(self.time_zone).to_date
    end

    def yearly_orders
      orders_between (1.year.ago + 1.day).in_time_zone(self.time_zone).to_date, Time.current.in_time_zone(self.time_zone).to_date
    end

    def orders_between(start_date, end_date, states = ApprovedStates)
      sales_orders.where('delivery_date BETWEEN ? AND ? AND state IN (?)', start_date, end_date, states).sum(:total)
    end

    def orders_count_between(start_date, end_date, states = ApprovedStates)
      sales_orders.approved.where('delivery_date BETWEEN ? AND ? AND state IN (?)', start_date, end_date, states).count
    end

    def valid_bill_address_attrs
      unless bill_address.try(:address1).present? && bill_address.try(:state).present? && bill_address.try(:zipcode).present? && bill_address.try(:city).present?
        errors.add(:bill_address_id, "is invalid")
      end
    end

    def setup_vendor_taxonomy
      self.taxonomies.create(name: self.name)
    end

    def generate_css(header_background, header_text, sidebar_background, sidebar_text)
      @header_background_color = header_background
      @header_text_color = header_text
      @sidebar_background_color = sidebar_background
      @sidebar_text_color = sidebar_text
      template = File.read("#{Rails.root}/app/models/spree/vendor_styles.css.erb")
      ERB.new(template).result(binding)
    end

    def self.darken_color(hex_color, amount=0.4)
      hex_color = hex_color.gsub('#','')
      rgb = hex_color.scan(/../).map {|color| color.hex}
      rgb[0] = (rgb[0].to_i * amount).round
      rgb[1] = (rgb[1].to_i * amount).round
      rgb[2] = (rgb[2].to_i * amount).round
      "#%02x%02x%02x" % rgb
    end

    def self.lighten_color(hex_color, amount=0.6)
      hex_color = hex_color.gsub('#','')
      rgb = hex_color.scan(/../).map {|color| color.hex}
      rgb[0] = [(rgb[0].to_i + 255 * amount).round, 255].min
      rgb[1] = [(rgb[1].to_i + 255 * amount).round, 255].min
      rgb[2] = [(rgb[2].to_i + 255 * amount).round, 255].min
      "#%02x%02x%02x" % rgb
    end

    def min_lead_days
      Spree::Variant.joins(:product).where('spree_products.vendor_id = ?', self.id).minimum('spree_variants.lead_time')
    end

    def next_available_delivery_date(account = nil, time = Time.current)
      today = time.in_time_zone(time_zone).to_date
      next_day = today + min_lead_days.days
      next_day += 1.day if after_cutoff?(time)

      if account
        7.times do
          next_day_num = next_day.wday.to_s
          return next_day if account.deliverable_days[next_day_num]
          next_day += 1.day
        end
      end

      next_day
    end
    def after_cutoff?(time = Time.current)
      return false if order_cutoff_time.blank?
      time.in_time_zone(time_zone) > order_cutoff_time.in_time_zone(time_zone)
    end
    def before_cutoff?(time = Time.current)
      !after_cutoff?(time)
    end

    def logo
      logos.first if logos.any?
    end

    def banner_image_url
      banner_image.try(:attachment).try(:url)
    end

    def cutoff_time_today
      self.order_cutoff_time.in_time_zone(self.time_zone)
    end

    def send_daily_summary
      # convert string to datetime in vendor timezone
      cutoff_datetime = self.order_cutoff_time.in_time_zone(self.time_zone)
                                              .in_time_zone('UTC') #convert to UTC for database comparisons

      # based on the order cutoff for the current day, we find the orders completed in the last 24 hours
      order_ids = self.sales_orders
                      .where(completed_at: (cutoff_datetime - 1.day..cutoff_datetime))
                      .where(state: InvoiceableStates)
                      .ids
      Spree::VendorMailer.daily_summary_email(order_ids).deliver_now unless order_ids.empty?
    end

    def send_daily_shipping_reminder
      cutoff_datetime = self.order_cutoff_time.in_time_zone(self.time_zone) + 1.hour
      # based on the order cutoff for the current day, we find the orders completed in the last 24 hours
      order_ids = self.sales_orders
                      .where(delivery_date: cutoff_datetime-1.day..cutoff_datetime)
                      .where(state: ['complete','approved'])
                      .ids
      Spree::VendorMailer.daily_shipping_reminder_email(order_ids).deliver_now unless order_ids.empty?
    end

    def send_daily_low_stock_notification
      Spree::VendorMailer.low_stock_email(self.id).deliver_now
    end

    def name_for_integration
      "Customer: #{self.name}"
    end

    def has_integration?(integration_key)
      self.integration_items.where(integration_key: integration_key).any? rescue nil
    end


    def page_sizes
      ::PDF::Core::PageGeometry::SIZES.keys
    end

    def page_layouts
      %w(landscape portrait)
    end

    def use_sequential_order_number?
      order_next_number.to_i > 0
    end

    def use_sequential_credit_memo_number?
      credit_memo_next_number.to_i > 0
    end

    def use_sequential_invoice_number?
      self.multi_order_invoice || self.use_separate_invoices && self.next_number.to_i > 0
    end

    def order_or_invoice_text
      if self.multi_order_invoice || self.use_separate_invoices
        'Invoice'
      else
        'Order'
      end
    end

    def increase_invoice_number!
      len = self.next_number.to_s.length
      num = self.next_number.to_i + 1
      len2 = num.to_s.length
      pad_length = [len - len2, 0].max
      self.next_number = "#{'0' * pad_length}#{num}"
      self.save
      self.next_number
    end

    def generate_invoice_number
      invoice_number = "#{invoice_prefix.to_s.strip}#{next_number}"
      if self.use_sequential_invoice_number?
        while self.sales_invoices.exists?(number: invoice_number) do
          invoice_number = "#{invoice_prefix.to_s.strip}#{self.increase_invoice_number!}"
        end
      end

      invoice_number
    end

    def order_default_prefix
      "#{DEFAULT_ORDER_PREFIX}#{id}-"
    end

    def font_faces
      ::Prawn::Font::AFM::BUILT_INS.reject do |font|
        font =~ /zapf|symbol|bold|italic|oblique/i
      end
    end

    def font_sizes
      (7..14).to_a
    end

    def logo_scaling
      logo_scale.to_f / 100
    end

    def update_account_names
      self.vendor_accounts.each do |account|
        account.update_columns(fully_qualified_name: account.set_fully_qualified_name)
        account.save
      end
    end

    def set_up_tax_categories
      name = "Taxable" # default Taxable category for vendor set up automatically when company is created
      tax_category = self.tax_categories.create!(name: name, tax_code: "Tax", description: "Default Tax Category" )
      name = "Nontaxable" # default Taxable category for vendor set up automatically when company is created
      tax_category = self.tax_categories.create!(name: name, tax_code: "Non", description: "Default Non-Tax Category" )
    end

    def set_up_default_permisssion_groups
      self.permission_groups.create!(name: 'Owner Access', permissions: Spree::Permission.owner_permissions)
      self.permission_groups.create!(name: 'Staff Access', permissions: Spree::Permission.staff_permissions)
      self.permission_groups.create!(name: 'Operations', permissions: Spree::Permission.operations_permissions)
    end

    def set_up_customer_viewable_attribute
      self.create_customer_viewable_attribute
    end

    def variants_for_purchase
      products_with_variants_ids = self.products.joins(:variants).distinct.ids
      if products_with_variants_ids.present?
        self.variants_including_master.where(
          'spree_products.for_purchase = ? and ((is_master = ? and product_id in (?)) or (is_master = ? and product_id not in (?)))',
          true, false, products_with_variants_ids, true, products_with_variants_ids
        )
      else
        self.variants_including_master.where('spree_products.for_purchase = ?', true)
      end
    end

    def variants_for_purchase_from(vendor_account)
      return variants_for_purchase unless vendor_account
      var_ids = vendor_account.vendor_variants.pluck(:variant_id)
      # return variants_for_purchase unless var_ids.present?
      products_with_variants_ids = self.products.joins(:variants).distinct.ids
      if products_with_variants_ids.present?
        self.variants_including_master.where(
          'spree_products.for_purchase = ? and (
            (is_master = ? and product_id in (?))
            or (is_master = ? and product_id not in (?))
          ) and (
            spree_variants.purchase_from_any = ?
            or spree_variants.id in (?)
          )',
          true, false, products_with_variants_ids, true, products_with_variants_ids, true, var_ids
        )
      else
        self.variants_including_master.where(
          'spree_products.for_purchase = ? and
          (
            spree_variants.purchase_from_any = ? or
            spree_variants.id in (?)
          )',
          true, true, var_ids)
      end
    end

    def variants_for_sale
      products_with_variants_ids = self.products.joins(:variants).distinct.ids
      if products_with_variants_ids.present?
        self.variants_including_master.includes(:product).where(
          'spree_variants.discontinued_on is null and spree_products.for_sale = ? and ((is_master = ? and product_id in (?)) or (is_master = ? and product_id not in (?)))',
          true, false, products_with_variants_ids, true, products_with_variants_ids
        )
      else
        self.variants_including_master.includes(:product).where('spree_products.for_sale = ? and spree_variants.discontinued_on is null', true)
      end
    end

    def index_of_avv(avv, ransack_params = {})
      return unless avv
      current_avvs = avvs.where(account_id: avv.account_id)
                         .where(variant_id: variants_for_sale.ids)
                         .visible
                         .includes(:variant)
                         .ransack(ransack_params)

      if cva.try(:variant_nest_name)
        current_avvs.sorts = cva.try(:associated_default_sort, :variant, :variant) if current_avvs.sorts.empty?
      else
        current_avvs.sorts = cva.try(:associated_default_sort, :flat_variant, :variant) if current_avvs.sorts.empty?
      end

      current_avvs.result
                  .pluck(:id)
                  .index(avv.id)
    end

    def next_avv(avv, current_avv_index, ransack_params = {})
      return unless avv && current_avv_index
      current_avvs = avvs.where(account_id: avv.account_id)
                         .where(variant_id: variants_for_sale.ids)
                         .visible
                         .includes(:variant)
                         .ransack(ransack_params)

      if cva.try(:variant_nest_name)
        current_avvs.sorts = cva.try(:associated_default_sort, :variant, :variant) if current_avvs.sorts.empty?
      else
        current_avvs.sorts = cva.try(:associated_default_sort, :flat_variant, :variant) if current_avvs.sorts.empty?
      end

      n_avv = current_avvs.result.offset(current_avv_index + 1).first
      n_avv ||= current_avvs.result.first

      n_avv.try(:id) == avv.id ? nil : n_avv
    end

    def prev_avv(avv, current_avv_index, ransack_params = {})
      return unless avv && current_avv_index
      current_avvs = avvs.where(account_id: avv.account_id)
          .where(variant_id: variants_for_sale.ids)
          .visible
          .includes(:variant)
          .ransack(ransack_params)

      if cva.try(:variant_nest_name)
        current_avvs.sorts = cva.try(:associated_default_sort, :variant, :variant) if current_avvs.sorts.empty?
      else
        current_avvs.sorts = cva.try(:associated_default_sort, :flat_variant, :variant) if current_avvs.sorts.empty?
      end
      if current_avv_index > 0
        p_avv = current_avvs.result.offset(current_avv_index - 1).first
      else
        p_avv = current_avvs.result.last
      end
      p_avv ||= current_avvs.result.last

      p_avv.try(:id) == avv.id ? nil : p_avv
    end

    def variants_for_sale_with_inactive
      products_with_variants_ids = self.products.joins(:variants).distinct.ids
      if products_with_variants_ids.present?
        self.variants_including_master.where(
          'spree_products.for_sale = ? and ((is_master = ? and product_id in (?)) or (is_master = ? and product_id not in (?)))',
          true, false, products_with_variants_ids, true, products_with_variants_ids
        )
      else
        self.variants_including_master.where('spree_products.for_sale = ?', true)
      end
    end

    def products_for_purchase
      self.products.for_purchase
    end

    def products_for_sale
      self.products.for_sale
    end

    def can_mark_paid?
      mark_paid_method.present?
    end

    def mark_paid_method
      payment_methods.where(mark_paid: true).first
    end

    def can_select_delivery_from_some?
      self.vendors.distinct.any?{|vendor| vendor.selectable_delivery }
    end

    def show_account_balance?
      self.show_account_balance
    end
    def any_vendor_using_separate_invoices?
      self.vendors.distinct.any?{|vendor| vendor.use_separate_invoices }
    end
    def any_vendor_showing_account_balance?
      self.vendor_accounts.any?{|account| account.should_see_balance? }
    end
    def any_vendor_showing_account_spend?
      self.vendor_accounts.any?{|account| account.should_see_spend? }
    end
    def any_vendor_using_po_numbers?
      self.vendors.distinct.any?{|vendor| vendor.use_po_number }
    end

    def accepts_payments?
      subscription_includes?('payments') && self.payment_methods.active.any?
    end

    def subscription_includes?(feature)
      Spree::Subscription.included_in_plan?(self.subscription, feature.to_s) rescue false
    end
    def subscription_limit(feature)
      Spree::Subscription.limit(self.subscription, feature.to_s) rescue nil
    end
    def no_subscript_limit(feature)
      subscription_limit(feature).nil?
    end
    def within_subscription_limit?(feature, count)
      return true if no_subscript_limit(feature)
      count < subscription_limit(feature)
    end

    def any_vendor_has_payment_methods?
      self.vendors.distinct.any?{|v| v.payment_methods.active.exists? }
    end
    def any_vendor_view_order_payments?
      self.vendors.distinct.any?{|v| v.cust_can_view?('order', 'payment_state') }
    end
    def any_vendor_view_invoice_payments?
      self.vendors.distinct.any?{|v| v.cust_can_view?('invoice', 'payment_state') }
    end

    def vendor_order_date_text
      order_name = self.vendors.first.order_date_text
      self.vendors.distinct.all? { |v| v.order_date_text == order_name } ? "#{order_name.capitalize}" : "Ship/Delivery"
    end

    def cust_can_view?(obj_class_str, attribute)
      customer_viewable_attribute.send("#{obj_class_str}").fetch(attribute) rescue false
    end

    def display_shipping_group_class
      if self.try(:order_date_text).present?
        "#{self.order_date_text.capitalize} Schedule"
      else
        "Delivery Schedule"
      end
    end

    def update_cart_numbers
      sales_orders.where(state: 'cart').find_each do |order|
        order.update_columns(number: order.generate_number(renumber: true))
      end
    end

    def track_order_class?
      self.try(:txn_class_type) == 'orders'
    end

    def track_line_item_class?
      self.try(:txn_class_type) == 'line_items'
    end

    def nest_variant_names?
      self.cva.try(:variant_nest_name)
    end

    def setup_email_templates(overwrite = false)
      Dir[Rails.root.join('app', 'views', '**', '*.liquid')].each do |liquid_template_filepath|
        next if liquid_template_filepath.include? "shared" # skip creating templates if liquid file is a partial
        slug = File.basename(liquid_template_filepath, '.liquid')
        create_email_template(slug, liquid_template_filepath, overwrite)
      end
    end

    def find_or_create_email_template(mailer_name, slug, overwrite = false)
      file_name = "#{slug}.liquid"
      liquid_template_filepath = Rails.root.join('app', 'views', 'mailers', mailer_name.underscore.to_sym.to_s, file_name).to_s
      return create_email_template(slug, liquid_template_filepath, overwrite)
    end

    def create_email_template(slug, liquid_template_filepath, overwrite = false)

      template =  self.email_templates.find_or_initialize_by(slug: slug)

      if (template.persisted? && overwrite) || template.new_record?
        file = File.new(liquid_template_filepath, 'r')

        # add template meta
        template.attributes = File.open(file) do |f|
          attr = YAML.load(f)
          attr.is_a?(Hash) ? attr : {}
        end

        # scope to vendor
        template.vendor_id = self.id

        # parse and save body
        contents = file.read
        match = contents.match(/(---+(.|\n)+---+)/)
        template.body = contents.gsub(match[1], '').strip if match

        template.file_path = liquid_template_filepath.sub!(Rails.root.to_s,"")

        unless template.save
          self.errors.add(:base, "Template did not save. Error: #{template.errors.messages.to_s}")
          Airbrake.notify(
            error_message: "#{errors.join(';')}",
            parameters:
            {
              company_id: self.id,
              template_slug: slug
            }
          )
        end

        # print_errors if needed
        unless template.valid?
          puts 'ERROR -- There was one or more validation errors while uploading:'
          puts "  Email Template: #{liquid_template_filepath}"
          template.errors.each do |attribute, error|
            puts "  -> #{attribute} #{error}"
          end
        end
      end

      template
    end


    extend FriendlyId
      friendly_id :name, use: [:slugged, :finders]

    private

    def next_numbers_presence
      if next_number.blank?
        errors.add(:base, "Next invoice number can't be blank")
      end
      if order_next_number.blank?
        errors.add(:base, "Next order number can't be blank")
      end
      if po_order_next_number.blank?
        errors.add(:base, "Next purchase order number can't be blank")
      end

      errors.empty?
    end

    def included_in_subscription
      valid = true
      if self.track_inventory && !subscription_includes?('inventory')
        self.errors.add(:base, 'Inventory tracking is not supported with your current subscription')
        valid = false
      end
      if self.lot_tracking && !subscription_includes?('lot_tracking')
        self.errors.add(:base, 'Lot tracking is not supported with your current subscription')
        valid = false
      end

    end

    def adjust_subscription_accessibles
      unless subscription_includes?('payments')
        payment_methods.where(active: true)
                       .where.not(type: NON_CREDIT_CARD_TYPES)
                       .update_all(active: false)
      end
    end

  end
end
