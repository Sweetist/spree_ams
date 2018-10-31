Spree::Variant.class_eval do
  include Spree::Dirtyable
  include Spree::DirtyAssociations
  include Spree::Integrationable
  include Spree::Variant::Channel::Sweetist
  include Spree::Variant::Weight
  include Spree::Variant::Lots
  extend Spree::Variant::Export

  COSTING_METHODS = %w[fixed last avg sum].freeze
  NO_COMPONENT_COSTING_METHODS = %w[fixed last avg].freeze

clear_validators! #needed to customize the uniquenss validation
  # these two are copied from Spree after clearing validators
  before_validation :set_cost_currency
  before_validation :set_order_quantities
  validates :lead_time, :weight, presence: true
  validates :incremental_order_quantity, numericality: {greater_than: 0}
  validates :minimum_order_quantity, numericality: {greater_than_or_equal_to: 0}
  validates_inclusion_of :dimension_units,
    in: Sweet::Application.config.x.dimension_units.to_h.keys,
    message: "must be in the list: #{Sweet::Application.config.x.dimension_units.to_h.keys.join(', ')}",
    allow_blank: true
  validates_inclusion_of :weight_units,
    in: Sweet::Application.config.x.weight_units.to_h.keys,
    message: "must be in the list: #{Sweet::Application.config.x.weight_units.to_h.keys.join(', ')}",
    allow_blank: true
  validate :check_price
  validate :uniqueness_of_sku_for_vendor
  validate :sku_presence
  validate :pack_size_or_option_value_presence
  validate :price_presence
  validate :can_deactivate?, if: Proc.new{|v| v.should_validate_deactivation }

  has_one :vendor, through: :product

  belongs_to :preferred_vendor_account, class_name: 'Spree::Account', foreign_key: :preferred_vendor_account_id, primary_key: :id

  has_many :lots
  has_many :stock_item_lots, through: :stock_items, source: :stock_item_lots
  has_many :assembly_build_parts
  has_many :assembly_builds, class_name: 'Spree::AssemblyBuild', foreign_key: :assembly_id, primary_key: :id

  has_many :standing_line_items, class_name: 'Spree::StandingLineItem', foreign_key: :variant_id, primary_key: :id
  has_many :standing_orders, through: :standing_line_items, source: :standing_order
  belongs_to :transaction_class, class_name: "Spree::TransactionClass", foreign_key: :txn_class_id, primary_key: :id

  has_many :account_viewable_variants, class_name: 'Spree::AccountViewableVariant',
    foreign_key: :variant_id, primary_key: :id, dependent: :destroy
  has_many :accounts, through: :account_viewable_variants, source: :account
  has_many :variant_vendors, class_name: 'Spree::VariantVendor',
    foreign_key: :variant_id, primary_key: :id, dependent: :destroy
  has_many :vendor_accounts, through: :variant_vendors, source: :vendor_account
  has_many :classifications, dependent: :delete_all, inverse_of: :variant, after_add: :make_dirty
  has_many :taxons, through: :classifications, before_remove: :remove_taxon

  has_many :variant_price_lists, class_name: 'Spree::PriceListVariant',
    foreign_key: :variant_id, primary_key: :id, inverse_of: :variant, dependent: :destroy
  has_many :price_lists, through: :variant_price_lists, source: :price_list

  alias_attribute :avvs, :account_viewable_variants
  alias_attribute :step_size, :incremental_order_quantity
  alias_attribute :fixed_cost_price, :cost_price

  has_one :default_price,
        #  -> { where currency: self.variant.vendor.currency },
        class_name: 'Spree::Price',
        dependent: :destroy

  has_paper_trail class_name: 'Spree::Version'

  accepts_nested_attributes_for :prices, :reject_if => :all_blank, :allow_destroy => true
  accepts_nested_attributes_for :option_values
  accepts_nested_attributes_for :stock_items
  accepts_nested_attributes_for :parts_variants, allow_destroy: true
  accepts_nested_attributes_for :variant_price_lists, allow_destroy: true
  before_create :set_cost_currency
  before_create :set_from_product
  before_save :set_default_price, if: :variant_is_persisted?

  after_create :set_default_price
  after_save :set_fully_qualified_name, on: [:create, :update]
  after_save :update_avv_visibility
  after_save :set_purchase_from_any
  after_commit :notify_integration_create, on: :create
  after_commit :notify_integration, unless: Proc.new { |variant| variant.is_master? && variant.product.has_variants? }, on: :update

  after_commit :set_viewable_variants, on: :create
  after_update :update_viewable_variant_prices, if: :avv_related_changes?
  after_update :update_components_cost, if: :any_costing_changes?

  scope :inventory, (-> { where(variant_type: INVENTORY_TYPES.keys) })
  scope :lot_tracked, (-> { where(lot_tracking: true) })
  scope :non_lot_tracked, (-> { where(lot_tracking: false) })

  attr_accessor :price_changed, :synchronous_avv_create, :should_validate_deactivation

  # attr_default :variant_type, 'inventory_item'

  # Ransack arguments from Spree here for reference only.  Do not uncomment or override.
  # To add additional properties use +=
  #
  # PRODUCTS
  # self.whitelisted_ransackable_associations = %w[stores variants_including_master master variants]
  # self.whitelisted_ransackable_attributes = %w[description name slug]
  # VARIANTS
  # self.whitelisted_ransackable_associations = %w[option_values product prices default_price]
  # self.whitelisted_ransackable_attributes = %w[weight sku]

  self.whitelisted_ransackable_attributes += %w[lead_time pack_size fully_qualified_name variant_type discontinued_on weight full_display_name default_display_name display_name]
  self.whitelisted_ransackable_associations += %w[taxons stock_items stock_locations prices account_viewable_variants]

  has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy
  has_many :integration_actions, as: :integrationable, class_name: 'Spree::IntegrationAction'

  attr_default :custom_attrs do
    {}
  end

  def vendor_account_ids=(arr)
    super(arr.reject(&:blank?).map(&:to_i))
  end

  def dirtyable_associations
    %i[prices variant_price_lists]
  end

  def allow_sync_inventory_for(integration_item)
    return false unless should_track_inventory?
    result = sync_for_item(integration_item)
    return false if result[:result] == false
    true
  end

  def sync_for_item(item)
    return super if item.sales_channel? == false
    return super if product.sync_to_sales_channels.include?(item)
    { result: false,
      reason: I18n.t('integrations.sync_disabled_in_settings') }
  end

  def self.active(currency = nil)
    # override method from Spree
    # joins(:prices).where(deleted_at: nil).where('spree_prices.currency' => currency || Spree::Config[:currency]).where('spree_prices.amount IS NOT NULL')
    where(deleted_at: nil, discontinued_on: nil)
  end

  def self.low_stock
    joins(stock_items: :stock_location)
    .where('spree_stock_locations.active = ?', true)
    .where('spree_variants.variant_type in (?)', INVENTORY_TYPES.keys)
    .where('spree_stock_items.min_stock_level IS NOT NULL AND spree_stock_items.count_on_hand <= spree_stock_items.min_stock_level')
    .distinct
  end

  def non_inventroy_in_stock_text
    return '' if vendor.try(:cva).try(:catalog_stock_level_in_stock_text).blank?
    Spree.t(:in_stock)
  end

  def inventory_in_stock_text(count)
    text = vendor.try(:cva).try(:catalog_stock_level_in_stock_text)
    return '' if text.blank?
    if text == 'remaining_stock'
      Spree.t(:remaining_stock, count: count)
    else
      Spree.t(:in_stock)
    end
  end

  def display_stock_level(sum_stock = false, location = nil, qty = 0, line_item = nil)
    return non_inventroy_in_stock_text unless should_track_inventory? || (is_bundle? && parts.present?)
    sum_stock = true unless location
    show_stock_warnings = vendor.try(:cva).try(:catalog_stock_level_show)
    in_stock_text = vendor.try(:cva).try(:catalog_stock_level_in_stock_text)
    if is_bundle?
      part_messages = []
      parts_variants.includes(:part).each do |part_variant|
        part = part_variant.part
        part_message = part.display_stock_level(
          sum_stock, location, (part_variant.count * line_item.try(:quantity).to_f), line_item
        )
        return part_message if part_message == Spree.t(:out_of_stock)
        part_messages << part_message
      end

      return Spree.t(:backordered) if part_messages.any? {|m| m == Spree.t(:backordered) }
      return Spree.t(:insufficient_stock) if part_messages.any? {|m| m.start_with?(Spree.t(:insufficient_stock))}
      return Spree.t(:bundle_low_stock) if part_messages.any? {|m| m.present? }
      return ''
    elsif sum_stock
      backorderable = backorderable_at(:any)
      is_backordered = total_on_hand <= 0 && backorderable
      if is_backordered && (show_stock_warnings || in_stock_text.present?)
        Spree.t(:backordered)
      elsif is_backordered
        ''
      elsif total_on_hand <= 0
        Spree.t(:out_of_stock)
      elsif line_item && total_on_hand < (qty - line_item.unit_sum(self)) && !backorderable
        Spree.t(:insufficient_stock_with_remaining, remaining: si.count_on_hand)
      elsif avg_low_stock? && show_stock_warnings
        Spree.t(:remaining_stock, count: total_on_hand)
      else
        inventory_in_stock_text(total_on_hand)
      end
    else
      si = stock_items.detect{|item| item.stock_location_id == location.id }
      is_backordered = si.count_on_hand <= 0 && si.backorderable?
      if is_backordered && (show_stock_warnings || in_stock_text.present?)
        Spree.t(:backordered)
      elsif is_backordered
        ''
      elsif si.count_on_hand <= 0
        Spree.t(:out_of_stock)
      elsif line_item \
        && si.count_on_hand < (qty - line_item.unit_sum(self)) \
        && !si.backorderable?
        Spree.t(:insufficient_stock_with_remaining, remaining: si.count_on_hand)
      elsif si.low_stock? && show_stock_warnings
        Spree.t(:remaining_stock, count: si.count_on_hand)
      else
        inventory_in_stock_text(si.count_on_hand)
      end
    end
  end

  def avg_low_stock?
    return false unless should_track_inventory?

    locations_with_minimums = stock_items.select do |si|
      si.stock_location.try(:active?) && !si.min_stock_level.blank?
    end
    return false if locations_with_minimums.empty?
    sum_min_stock_level = locations_with_minimums.sum { |si| si.min_stock_level }

    total_on_hand < sum_min_stock_level
  end

  def backorderable_at(location)
    return false unless location
    if location == :any
      stock_items.any?(&:backorderable)
    else
      si = stock_items.detect{|item| item.stock_location_id == location.id }
      si.try(:backorderable)
    end
  end

  def count_for_(part)
    parts_variants.find_by(part_id: part.id).try(:count) || 0
  end

  def unassigned_inventory_at(location)
    stock_items.where(stock_location: location).first
               .try(:unassigned_inventory_count) || 0
  end

  # return lot for self
  # self is the part of assembly
  def part_lot_for(assembly)
    return unless assembly.last_assembly_build
    assembly_build_parts.find_by(assembly_build: assembly.last_assembly_build)
                        .try(:stock_item_lot).try(:lot)
  end

  def last_assembly_build
    return unless assembly_builds
    assembly_builds.last
  end

  def self.view_editable_attributes
    #should return array of attributes
    [:lead_time, :pack_size, :sku]
  end

  def count_on_hand_in(stock_location_id)
    return 'N/A' unless should_track_inventory?
    item = stock_items.find_by(stock_location_id: stock_location_id)
    return 0 unless item
    item.count_on_hand
  end

  def notify_integration
    #add delay to allow for match.no_sync to be set
    Sidekiq::Client.push(
      'class' => VariantSync,
      'at' => Time.current.to_i + 2.seconds,
      'queue' => 'integrations',
      'args' => [self.id, self.product.vendor_id]
    ) if self.product.vendor.integration_items.where(variant_sync: true).any?
  end

  def can_sync?(integration_item)
    !!sync_for_item(integration_item).fetch(:result, true) rescue true
  end

  def name_for_integration
    "Product: #{self.full_display_name}"
  end

  def set_fully_qualified_name
    fq_name =
      if self.is_master?
        "#{self.product.name}"
      elsif self.option_values.present?
        "#{self.product.name}:#{self.ordered_option_values.pluck(:presentation).join(':')}"
      elsif self.pack_size.present?
        "#{self.product.name}:#{self.pack_size}"
      else
        "#{self.product.name}"
      end

    dd_name =
     if self.is_master?
       self.product.default_display_name
     elsif self.display_name.present?
       self.display_name
     else
       "#{self.product.default_display_name}:#{fq_name.split(':').slice(1..-1).join(':')}"
     end

    self.update_columns(
      fully_qualified_name: fq_name,
      default_display_name: dd_name,
      full_display_name: set_full_display_name(fq_name, dd_name, {skip_update: true})
    ) rescue ''
  end

  def set_full_display_name(fq_name, dd_name, options = {})
    # options can be :skip_update
    return dd_name if self.is_master?
    fd_name =
      if fq_name == dd_name
        fq_name
      elsif dd_name == self.display_name
        "#{self.product.default_display_name}:#{dd_name}"
      else
        dd_name
      end

    unless options[:skip_update]
      self.update_columns(full_display_name: fd_name)
    end

    fd_name
  end

  def fully_qualified_sku
    return sku if is_master?

    [product.master.sku, sku].join(':')
  end

  def ordered_option_values
    self.option_values.joins(option_type: :product_option_types)
      .where('spree_product_option_types.product_id = ?', self.product_id)
      .reorder('spree_product_option_types.position ASC')
  end

  def options_text
    ov = self.option_values.first
    if ov.try(:option_type)
      "#{ov.option_type.presentation}: #{ov.presentation}"
    else
      "#{ov.try(:presentation)}"
    end
  end

  def variant_name
    return full_display_name if is_master?
    begin
      full_display_name.to_s.split(':').slice(1..-1).join(':')
    rescue
      full_display_name
    end
  end
  def flat_or_nested_name
    return full_display_name if is_master?
    if self.vendor.try(:cva).try(:variant_nest_name)
      full_display_name
    else
      default_display_name
    end
  end

  def taxons_via_product
    product.taxons - taxons
  end

  def all_taxons
    (taxons + product.taxons).distinct
  end

  def description_string
    (is_master? ? product.description : variant_description).to_s
  end

  def display_minimum_order_quantity
    return Spree.t(:no_minimum) if minimum_order_quantity.blank? || minimum_order_quantity.zero?
    minimum_order_quantity.to_s
  end

  def line_for_csv
    line_base = [
      full_display_name,
      sku,
      pack_size
    ]
    stock_items = self.stock_items.joins(:stock_location)
                      .where('spree_stock_locations.vendor_id = ? and spree_stock_locations.active = ?', vendor.id, true)
                      .order('spree_stock_locations.name ASC')
    stock_items.each do |stock_item|
      line_base += [
        stock_item.on_hand,
        stock_item.available,
        stock_item.committed
      ]
    end
    total_committed = self.total_committed
    total_available = self.total_available
    total_on_hand = [total_available + total_committed, 0].max
    line_base += [
      total_on_hand,
      total_available,
      total_committed
    ]
  end

  def should_show_parts?
    (is_assembly? || is_bundle?) && parts.present? && show_parts
  end

  def is_assembly?
    self.variant_type == 'inventory_assembly'
  end

  def assembly?
    self.parts.any?
  end

  def is_bundle?
    self.variant_type == 'bundle'
  end

  def has_parts?
    self.parts.any?
  end

  def can_have_parts?
    is_bundle? || is_assembly?
  end

  def taxable?
    self.tax_category && self.tax_category.tax_code.to_s.downcase != 'non'
  end

  def can_deactivate?
    assemblies_parts = Spree::AssembliesPart.where(part_id: id)
                                            .includes(:part, :assembly)
    if assemblies_parts.present?
      assemblies_parts.map do |assembly_part|
        self.errors.add(
          :base,
          Spree.t('errors.discontinue_errors.is_part',
                  part_name: assembly_part.part.full_display_name,
                  assembly_name: assembly_part.assembly.full_display_name)
        )
      end
      self.discontinued_on = nil
      false
    else
      true
    end
  end

  def discontinue
    return product.discontinue if is_master?

    if can_deactivate?
      self.update_columns(discontinued_on: Time.current)
      true
    else
      false
    end
  end

  def discontinued?
    !discontinued_on.blank?
  end

  def should_make_visible?
    self.visible_to_all && product.for_sale && !(self.is_master? && product.has_variants?)
  end

  def visible_to_text
    return 'All accounts' if visible_to_all
    "#{avvs.visible.count} of #{accounts.active.count} accounts"
  end

  def make_available
    unless self.vendor.within_subscription_limit?(
              'products', (self.vendor.showable_variants.active.count + 1)
            )
      limit = self.vendor.subscription_limit('products')
      self.errors.add(:base, "Your subscription is limited to #{limit} #{'product'.pluralize(limit)}")
      return false
    end

    if self.is_master?
      self.product.make_available
    else
      unless product.discontinued_on.nil?
        product.update_columns(discontinued_on: nil)
        product.master.update_columns(discontinued_on: nil)
      end
      self.update_columns(discontinued_on: nil)
    end

    true
  end

  def active
    self.discontinued_on.blank?
  end
  def active=(value)
    val = nil
    val = value.to_bool rescue nil
    if !val && discontinued_on.blank?
      self.should_validate_deactivation = true
      self.discontinued_on = Time.current
    elsif val && discontinued_on.present?
      self.make_available
    end
  end

  def active?
    active
  end

  def save_part(part_params)
    form = Spree::AssignPartToBundleForm.new(self.product, part_params)
    form.submit ? true : form.errors.full_messages.to_sentence
  end

  # def total_on_hand
  #   if self.should_track_inventory?
  #     stock_items.active.sum(:count_on_hand)
  #   else
  #     Float::INFINITY
  #   end
  # end

  def total_committed
    stock_items.active.sum(:committed)
  end

  def total_available
    if self.should_track_inventory?
      stock_items.active.sum(:available)
    else
      Float::INFINITY
    end
  end

  def remove_parts
    self.parts = []
  end

  def remove_taxon(taxon)
    self.dirty = true
    removed_classifications = classifications.where(taxon: taxon)
    removed_classifications.each(&:remove_from_list)
  end

  def variant_is_persisted?
    self.persisted?
  end

  def dimensions
    [width, height, depth].reject(&:blank?)
  end

  def is_past_cutoff?(delivery_date, now = Time.current)
    return false unless delivery_date.present?
    delivery_date = delivery_date.to_date
    if (delivery_date - lead_time.days) == now.in_time_zone(vendor.time_zone).to_date
      if now.in_time_zone(vendor.time_zone) > vendor.order_cutoff_time.in_time_zone(vendor.time_zone)
        return true
      end
    elsif (delivery_date - lead_time.days) < now.in_time_zone(vendor.time_zone).to_date
      return true
    end

    return false

  end

  def uniqueness_of_sku_for_vendor
    return false if product.vendor.nil?
    return true if self.is_master && self.product.has_variants?

    # product_matches = Spree::Variant.joins(:product).select('count(spree_variants.id)').where('spree_products.vendor_id = ? AND spree_variants.is_master = ? AND spree_variants.sku = ?', self.product.vendor_id, true, self.sku).where.not('spree_products.id = ?', self.product_id).group( 'spree_products.id' ).having( 'count( spree_variants.id ) = ?', 1).present?
    # variant_matches = Spree::Variant.joins(:product).where('spree_products.vendor_id = ? AND spree_variants.is_master = ? AND spree_variants.sku = ?', self.product.vendor_id, false, self.sku).where.not('spree_variants.id = ?', self.id).present?

    if self.product_id
      # product_ids = product.vendor.products.joins(:master).pluck('spree_products.id') - vendor.products.joins(:variants).pluck('spree_products.id')
      # product_matches = Spree::Variant.joins(:product).select('count(spree_variants.id)').where('spree_products.id IN (?) AND spree_products.vendor_id = ? AND spree_variants.sku = ?', product_ids, self.product.vendor_id, self.sku).where.not('spree_variants.product_id = ?', self.product_id).group( 'spree_products.id' ).having( 'count( spree_variants.id ) = ?', 1).present?
      product_matches = Spree::Variant.joins(:product).select('count(spree_variants.id)').where('spree_products.vendor_id = ? AND spree_variants.sku = ?', self.product.vendor_id, self.sku).where.not('spree_variants.product_id = ?', self.product_id).group( 'spree_products.id' ).having( 'count( spree_variants.id ) = ?', 1).present?
    else
      product_matches = Spree::Variant.joins(:product).select('count(spree_variants.id)').where('spree_products.vendor_id = ? AND spree_variants.sku = ?', self.product.vendor_id, self.sku).group( 'spree_products.id' ).having( 'count( spree_variants.id ) = ?', 1).present?
    end
    if self.id
      variant_matches = Spree::Variant.joins(:product).where('spree_products.vendor_id = ? AND spree_variants.is_master = ? AND spree_variants.sku = ? AND spree_variants.id != ?', self.product.vendor_id, false, self.sku, self.id).present?
    else
      variant_matches = Spree::Variant.joins(:product).where('spree_products.vendor_id = ? AND spree_variants.is_master = ? AND spree_variants.sku = ?', self.product.vendor_id, false, self.sku).present?
      # variant_matches = Spree::Variant.joins(:product).where('spree_products.vendor_id = ? AND spree_variants.is_master = ? AND spree_variants.sku = ?', self.product.vendor_id, false, self.sku).present?
    end
    # product_matches = Spree::Variant.joins(:product).where('spree_products.vendor_id = ? AND spree_variants.is_master = ? AND spree_variants.sku = ?', var.product.vendor_id, true, var.sku).where('spree_variants.product_id != ?', var.product_id).group( 'spree_products.id, spree_variants.id' ).having( 'count( spree_variants.id ) = ?', 1).present?
    if product_matches || variant_matches
      errors.add(:sku, 'is already taken')
      false
    else
      true
    end
  end

  def sku_presence
    if sku.blank? && !is_master
      errors.add(:sku, "can't be blank")
      false
    else
      true
    end
  end

  def price_presence
    if price.blank? && !is_master
      errors.add(:price, "can't be blank")
      false
    elsif price < 0 && !is_master
      errors.add(:price, "must be greater then 0")
      false
    else
      true
    end
  end

  def pack_size_or_option_value_presence
    valid = true
    if pack_size.blank? && option_values.empty? && !is_master
      errors.add(:pack_size, "can't be blank if there are no option values")
      valid = false
    elsif pack_size.nil?
      errors.add(:pack_size, "can't be nil")
      valid = false
    end

    valid
  end

  def full_context
    "#{self.full_display_name} (#{self.sku})"
  end

  def set_cost_currency
    self.cost_currency = self.product.vendor.try(:currency)
  end

  def set_from_product
    self.assign_attributes(
      tax_category_id: self.product.tax_category_id,
      variant_type: self.product.product_type,
      track_inventory: INVENTORY_TYPES.has_key?(self.product.product_type),
      income_account_id: self.product.income_account_id,
      expense_account_id: self.product.expense_account_id,
      cogs_account_id: self.product.cogs_account_id,
      asset_account_id: self.product.asset_account_id
    )
  end

  def variant_or_product_type
    self.variant_type || self.product.try(:product_type)
  end
  #
  # We have to override set_option_value to assign vendor
  #
  # option_value = Spree::OptionValue.where(option_type_id: option_type.id, name: opt_value, vendor_id: self.vendor.id).first_or_initialize do |o|
  #
  def set_option_value(opt_name, opt_value)
    # no option values on master
    return if self.is_master

    option_type = Spree::OptionType.where(name: opt_name).first_or_initialize do |o|
      o.presentation = opt_name
      o.save!
    end

    current_value = self.option_values.detect { |o| o.option_type.name == opt_name }

    unless current_value.nil?
      return if current_value.name == opt_value
      self.option_values.delete(current_value)
    else
      # then we have to check to make sure that the product has the option type
      unless self.product.option_types.include? option_type
        self.product.option_types << option_type
      end
    end

    option_value = Spree::OptionValue.where(option_type_id: option_type.id, name: opt_value, vendor_id: self.vendor.id).first_or_initialize do |o|
      o.presentation = opt_value
      o.save!
    end

    self.option_values << option_value
    self.save
  end

  def check_price
    if price.nil? && Spree::Config[:require_master_price]
      raise 'No master variant found to infer price' unless (product && product.master)
      raise 'Must supply price for variant or master.price for product.' if self == product.master
      self.price = product.master.price
    end
    if currency.nil?
      self.currency = self.vendor.try(:currency) || Spree::Config[:currency]
    end
  end

  def price_changed?
    what_changed = self.what_changed?
    what_changed.changed? && what_changed.has_key?(:prices)
  end

  def variant_price_lists_changed?
    what_changed = self.what_changed?
    what_changed.changed? && what_changed.has_key?(:variant_price_lists)
  end

  #override method from Spree - leave blank
  def save_default_price

  end

  def should_track_inventory?
    # self.track_inventory? && self.product.try(:vendor).try(:track_inventory)
    # checking product type instead because track_inventory is set during an after callback
    # and could be inaccurate in a sidekiq job
    return false unless self.product.try(:vendor).try(:track_inventory)
    return false unless self.product.vendor.subscription_includes?('inventory')
    INVENTORY_TYPES.has_key?(self.product.product_type)
  end

  def for_sale?
    self.product.for_sale?
  end

  def for_purchase?
    self.product.for_purchase?
  end

  def is_visible_to?(account)
    return false if account.nil?
    !!self.account_viewable_variants.where(account_id: account.id).first.try(:visible)
  end

  def create_stock_items
    self.product.vendor.stock_locations.where(propagate_all_variants: true).each do |stock_location|
      stock_location.propagate_variant(self)
    end
  end

  def set_viewable_variants
    if self.synchronous_avv_create
      avv_ids = []
      Spree::Account.where(vendor_id: self.product.vendor_id).each do |account|
        avv = avvs.find_or_create_by(account_id: account.id)
        avv.find_eligible_promotions
        avv.cache_price(avv.eligible_promotions.unadvertised)
      end
    else
      Sidekiq::Client.push(
        'class' => VariantCreateAvvWorker,
        'queue' => 'critical',
        'args' => [self.id, self.product.vendor_id]
      )
    end
  end

  def update_viewable_variant_prices
    self.account_viewable_variants
        .where('recalculating != ?', Spree::AccountViewableVariant::RecalculatingStatus['enqueued'])
        .update_all(recalculating: Spree::AccountViewableVariant::RecalculatingStatus['backlog'])
    self.set_viewable_variants
  end

  def current_cost_price
    self.send("#{costing_method}_cost_price")
  end

  def weighted_avg_cost(qty, cost)
    toh = [0, total_on_hand.to_d].max
    if toh == Float::INFINITY
      ((cost_price + cost.to_d) / 2).round(2)
    else
      divisor = toh.to_d + qty
      return cost.to_d if divisor.zero?
      (((toh * cost_price) + (qty * cost.to_d)) / (divisor)).round(2)
    end
  end

  def sum_component_costs
    parts_variants.includes(:part).inject(0) do |sum, pv|
      sum + (pv.count.to_d * pv.part.current_cost_price.to_d).round(2)
    end
  end

  def update_components_cost
    new_component_cost = sum_component_costs
    return if new_component_cost == sum_cost_price

    update_columns(sum_cost_price: sum_component_costs)

    return unless vendor

    vendor.variants_including_master.joins(:parts_variants)
      .where(variant_type: BUILD_TYPES.keys)
      .where('spree_assemblies_parts.part_id = ?', self.id)
      .each {|assembly| assembly.update_components_cost}
  end

  def all_images
    (images + product.images).uniq
  end

  def multiple_images?
    (images + product.images).count > 1
  end

  def text_options_arr
    text_options.to_s.split(',').map(&:strip)
  end

  def assign_account(acc, acc_type = nil)
    category_name = Spree::ChartAccountCategory.find_by_id(acc.try(:chart_account_category_id)).try(:name)
    return unless category_name || acc_type

    ["Income Account", "Cost of Goods Sold Account", "Asset Account", "Expense Account"]

    acc_type ||= case category_name
    when 'Income Account'
      'income_account_id'
    when 'Cost of Goods Sold Account'
      'cogs_account_id'
    when 'Asset Account'
      'asset_account_id'
    when 'Expense Account'
      'expense_account_id'
    end

    self.method("#{acc_type}=").call(acc.id)
    self.method("#{acc_type}").call
    self.product.method("#{acc_type}=").call(acc.id)
    self.product.method("#{acc_type}").call
  end

  def self.production_list(vendor, start_date, end_date, states, account_ids = [])
    sql_query = "
     SELECT
       spree_variants.id,
       spree_variants.full_display_name,
       spree_variants.sku,
       spree_variants.pack_size,
       spree_variants.pack_size_qty,
       spree_variants.weight,
       spree_variants.weight_units,
       SUM(spree_line_items.quantity) as quantity
     FROM
       spree_variants
     LEFT JOIN
       spree_line_items ON spree_line_items.variant_id = spree_variants.id
     LEFT JOIN
       spree_orders ON spree_orders.id = spree_line_items.order_id
     WHERE
       spree_variants.id IN (?)
     AND
       spree_orders.delivery_date BETWEEN ? AND ?
     AND
       spree_orders.state IN (?)"
     if account_ids.present?
       sql_query += " AND spree_orders.account_id IN (?) "
     end
     sql_query += "
     GROUP BY
       spree_variants.full_display_name,
       spree_variants.sku,
       spree_variants.pack_size,
       spree_variants.pack_size_qty,
       spree_variants.weight,
       spree_variants.weight_units,
       spree_variants.id
     ORDER BY
       spree_variants.full_display_name asc
    "
    sql_arr = [sql_query, vendor.showable_variants.ids, start_date, end_date, states]
    sql_arr << account_ids if account_ids.present?
    Spree::Variant.find_by_sql(sql_arr)
  end

  def self.full_production_list(vendor, start_date, end_date, states, account_ids = [])
    variants_with_qty = Spree::Variant.production_list(vendor, start_date, end_date, states, account_ids)
    variants_with_qty_ids = variants_with_qty.map(&:id)
    variants_with_qty_ids = [0] if variants_with_qty_ids.empty?
    sql_arr = [
      vendor.showable_variants.ids,
      start_date,
      end_date,
      states
    ]

    sql_query = "
     SELECT
       vars.id,
       vars.full_display_name,
       vars.sku,
       vars.pack_size,
       vars.pack_size_qty,
       vars.weight,
       vars.weight_units,
       SUM(spree_line_items.quantity) as quantity
     FROM
       spree_variants vars
     LEFT JOIN
       spree_line_items ON spree_line_items.variant_id = vars.id
     LEFT JOIN
       spree_orders ON spree_orders.id = spree_line_items.order_id
     WHERE
       vars.id IN (?)
     AND
       spree_orders.delivery_date BETWEEN ? AND ?
     AND
       spree_orders.state IN (?)"
    if account_ids.present?
      sql_query += " AND spree_orders.account_id IN (?) "
      sql_arr << account_ids
    end
    sql_query += "
     GROUP BY
       vars.full_display_name,
       vars.sku,
       vars.pack_size,
       vars.pack_size_qty,
       vars.weight,
       vars.weight_units,
       vars.id
     UNION
     SELECT
       spree_variants.id,
       spree_variants.full_display_name,
       spree_variants.sku,
       spree_variants.pack_size,
       spree_variants.pack_size_qty,
       spree_variants.weight,
       spree_variants.weight_units,
       NULL as quantity
     FROM
       spree_variants
     WHERE
       spree_variants.id IN (?)
     AND
       spree_variants.id NOT IN (?)
     GROUP BY
       spree_variants.full_display_name,
       spree_variants.sku,
       spree_variants.pack_size,
       spree_variants.pack_size_qty,
       spree_variants.weight,
       spree_variants.weight_units,
       spree_variants.id
     ORDER BY
       full_display_name asc
    "

    sql_arr += [
      vendor.showable_variants.ids,
      variants_with_qty_ids
    ]
    sql_arr.unshift(sql_query)
    Spree::Variant.find_by_sql(sql_arr)
  end

  private

  def notify_integration_create
    self.notify_integration
  end

  def update_avv_visibility
    return unless self.visible_to_all
    self.account_viewable_variants.update_all(visible: true)
  end

  def set_default_price
    default_price.currency = self.product.try(:vendor).try(:currency)
    if default_price_changed? || self.prices.any?{|price| price.changed?}
      default_price.save
      self.price_changed = true
      self.product.price_changed = true
    end
  end

  def set_order_quantities
    self.minimum_order_quantity = 0 if self.minimum_order_quantity.blank?
    self.incremental_order_quantity = 1 if self.incremental_order_quantity.blank?
  end

  def avv_related_changes?
    price_changed || new_record? || dirty || variant_price_lists_changed?
  end

  def any_costing_changes?
    cost_price_changed? || last_cost_price_changed? || avg_cost_price_changed? || costing_method_changed?
  end

  def set_purchase_from_any
    if self.purchase_from_any && self.vendor_accounts.present?
      self.update_columns(purchase_from_any: false)
    elsif !self.purchase_from_any && self.vendor_accounts.blank?
      self.update_columns(purchase_from_any: true)
    end
  end
end
