Spree::Product.class_eval do
  # include Spree::Dirtyable
  include Spree::DirtyAssociations

  PRODUCT_TYPES = {
    'inventory_item' => 'Inventory Item',
    'non_inventory_item' => 'Non Inventory Item',
    'service' => 'Service',
    'other_charge' => 'Other Charge',
    'bundle' => 'Bundle',
    'inventory_assembly' => 'Inventory Assembly'
  }.freeze
  PRODUCT_TYPE_CHART_ACCOUNTS = {
    'inventory_item' => [:income_account, :cogs_account, :asset_account],
    'non_inventory_item' => [:income_account, :expense_account],
    'service' => [:income_account, :expense_account],
    'bundle' => [],
    'inventory_assembly' => [:income_account, :cogs_account, :asset_account],
    'other_charge' => [:income_account, :expense_account]
  }.freeze

  INVENTORY_TYPES = {'inventory_item' => 'Inventory Item', 'inventory_assembly' => 'Inventory Assembly'}
  NON_INVENTORY_TYPES = {
                          'non_inventory_item' => 'Non Inventory Item',
                          'bundle' => 'Bundle',
                          'service' => 'Service',
                          'other_charge' => 'Other Charge'
                        }.freeze
  SERVICE_TYPES = {'service' => 'Service'}.freeze
  BUNDLE_TYPES = {'bundle' => 'Bundle'}.freeze
  NO_BUILD_TYPES =  {
                      'inventory_item' => 'Inventory Item',
                      'non_inventory_item' => 'Non Inventory Item',
                      'service' => 'Service',
                      'other_charge' => 'Other Charge'
                    }.freeze
  NON_INVENTORY_NO_BUILD_TYPES =  {
                                    'non_inventory_item' => 'Non Inventory Item',
                                    'service' => 'Service',
                                    'other_charge' => 'Other Charge'
                                  }.freeze
  BUILD_TYPES = {'bundle' => 'Bundle', 'inventory_assembly' => 'Inventory Assembly'}.freeze
  ACCOUNT_CATEGORIES = [:asset_account, :income_account, :cogs_account, :expense_account]

  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
  validates :available_on, presence: true
  validates :product_type, inclusion: { in: PRODUCT_TYPES.keys, message: "must be one of [#{PRODUCT_TYPES.values.join(', ')}]" }
  accepts_nested_attributes_for :variants, allow_destroy: true
  accepts_nested_attributes_for :master
  accepts_nested_attributes_for :variants_including_master
  accepts_nested_attributes_for :prices, :reject_if => :all_blank, :allow_destroy => true
  accepts_nested_attributes_for :product_option_types, reject_if: :reject_option_types, allow_destroy: true
  validates_associated :variants

  has_many :option_values, through: :variants, source: :option_values
  has_many :classifications, dependent: :delete_all, inverse_of: :product, after_add: :make_dirty #before_remove already declared in spree
  delegate_belongs_to :master, :lead_time
  delegate_belongs_to :master, :pack_size
  delegate_belongs_to :master, :weight_units
  delegate_belongs_to :master, :lot_tracking
  delegate_belongs_to :master, :should_track_lots?
  delegate_belongs_to :master, :should_show_parts?
  delegate_belongs_to :master, :show_parts

  validate :sku_presence_with_no_variants
  validate :permitted_product_type_changes
  validate :sale_or_purchase
  validate :can_deactivate?, if: Proc.new{|p| p.should_validate_deactivation}

  has_many :account_viewable_products, class_name: 'Spree::AccountViewableProduct',
    foreign_key: :product_id, primary_key: :id, dependent: :destroy
  has_many :account_viewable_variants, through: :variants_including_master, source: :account_viewable_variants
  alias_attribute :avvs, :account_viewable_variants

  has_many :viewable_by_accounts, ->{where('spree_account_viewable_products.visible = ?', true)}, through: :account_viewable_products, source: :account
  has_many :shipping_methods, ->{distinct}, through: :shipping_category
  has_many :stock_items, through: :variants_including_master

  has_many :standing_line_items, through: :variants_including_master, source: :standing_line_items
  has_many :standing_orders, through: :standing_line_items, source: :standing_order

  belongs_to :income_account, class_name: 'Spree::ChartAccount', foreign_key: :income_account_id, primary_key: :id
  belongs_to :expense_account, class_name: 'Spree::ChartAccount', foreign_key: :expense_account_id, primary_key: :id
  belongs_to :cogs_account, class_name: 'Spree::ChartAccount', foreign_key: :cogs_account_id, primary_key: :id
  belongs_to :asset_account, class_name: 'Spree::ChartAccount', foreign_key: :asset_account_id, primary_key: :id

  has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy

  has_paper_trail class_name: 'Spree::Version'

  has_many :product_integration_items, class_name: 'Spree::ProductIntegrationItems', dependent: :destroy
  has_many :sync_to_sales_channels, through: :product_integration_items,
                                    source: :integration_item
  scope :inventory, -> { where(product_type: INVENTORY_TYPES.keys) }
  scope :for_sale, -> { where(for_sale: true) }
  scope :for_purchase, -> { where(for_purchase: true) }
  scope :for_sale_and_purchase, -> { where(for_sale: true, for_purchase: true) }
  scope :for_sale_or_purchase, -> { where('for_sale = ? OR for_purchase = ?', true, true) }

  before_validation :ensure_build_type, on: :update
  before_save :new_variant?
  before_save :set_default_display_name
  before_save :set_master_name
  after_save :set_variant_fully_qualified_names, on: [:create, :update]#, if: Proc.new {|product| product.name_changed? } Need to check option types as well
  after_save :set_variant_attributes
  after_update :update_viewable_variant_prices, if: :avv_related_changes?
  after_commit :notify_integration

  attr_default :product_type, 'non_inventory_item'
  # product import stores variant type ID here. same goes for import_images Do not delete :)
  attr_accessor :variant_option_type_id
  attr_accessor :import_images
  attr_accessor :new_price
  attr_accessor :price_changed
  attr_accessor :should_validate_deactivation

  def sync_to_sales_channel_ids=(arr)
    super(arr.reject(&:blank?).map(&:to_i))
  end

  def notify_integration
    Sidekiq::Client.push(
      'class' => ProductSync,
      'queue' => 'integrations',
      'args' => [id]
    )
  end

  def notify_variants
    Spree::Variant.where(product_id: id).each do |variant|
      variant.notify_integration if vendor.integration_items.any?
    end
  end

  # System should run sync trigger for that integration item?
  # response is hash object
  # { result: true }  - trigger integration sync
  # { result: false, reason: 'Some no sync reason' } - no trigger, write reason
  # in action_log
  def sync_for_item(item)
    return super if item.sales_channel? == false
    return super if sync_to_sales_channels.include?(item)
    { result: false,
      reason: I18n.t('integrations.sync_disabled_in_settings') }
  end

  def self.view_editable_attributes
    #should return array of attributes
    []
  end

  def self.available(available_on = nil, currency = nil)
    joins(variants_including_master: :prices).where("spree_products.available_on <= ? AND spree_products.discontinued_on IS NULL", available_on || Time.current).distinct
  end
  search_scopes << :available

  def name_for_integration
    "Product: #{self.default_display_name}"
  end

  def should_track_inventory?
    return false unless self.vendor.subscription_includes?('inventory')
    self.vendor.track_inventory && self.variants_including_master.any?{ |variant| variant.track_inventory }
  end

  def assembly?
    is_bundle? && parts.present?
  end

  def is_assembly?
    self.product_type == 'inventory_assembly'
  end

  def is_bundle?
    self.product_type == 'bundle'
  end

  def has_variants_with_no_option_types
    ot_ids = self.option_type_ids
    self.option_values.pluck(:option_type_id).uniq.any?{|ot_id| !ot_ids.include?(ot_id) }
  end

  # Ransack arguments from Spree here for reference only.  Do not uncomment or override.
  # To add additional properties use +=
  #
  # PRODUCTS
  # self.whitelisted_ransackable_associations = %w[stores variants_including_master master variants]
  # self.whitelisted_ransackable_attributes = %w[description name slug]
  # VARIANTS
  # self.whitelisted_ransackable_associations = %w[option_values product prices default_price]
  # self.whitelisted_ransackable_attributes = %w[weight sku]

  self.whitelisted_ransackable_attributes += %w[pack_size lead_time price_range discontinued_on available_on product_type for_sale for_purchase can_be_part]
  self.whitelisted_ransackable_associations += %w[taxons]

  ransacker :product_sku do |parent|
    Arel.sql('spree_master_sku spree_variants_sku')
  end

  ransacker :product_lead_time do |parent|
    Arel.sql('spree_master_lead_time spree_variants_lead_time')
  end

  ransacker :product_pack_size do |parent|
    Arel.sql('spree_master_pack_size spree_variants_pack_size')
  end

  def promotion_ids
    self.account_viewable_variants.pluck(:promotion_ids).flatten.uniq
  end

  def price_range
    return [self.price] unless self.has_variants?
    prices = Spree::Price.where(currency: self.vendor.currency, variant_id: self.variant_ids)
    [prices.minimum(:amount), prices.maximum(:amount)].uniq
  end

  # returns true if any variants do not track inventory
  def any_variants_not_track_inventory?
    return true unless self.vendor.track_inventory
    if variants_including_master.loaded?
      variants_including_master.any? { |v| !v.track_inventory? }
    else
      variants_including_master.where(track_inventory: false).exists?
    end
  end

  def any_variants_has_display_name?
    variants.where.not(display_name: [nil, '']).present?
  end

  def showable_variants
    #We want to return a collection always here, not just master variant object
    self.has_variants? ? self.variants : self.variants_including_master
  end

  def showable_avvs
    Spree::AccountViewableVariant.where(variant_id: self.showable_variants.ids)
  end

  def make_viewable_to_all!
    self.showable_avvs.where(visible: false).update_all(visible: true)
  end

  def new_variant?
    self.new_price = self.variants.any? {|variant| variant.new_record?}
    true
  end

  # Override before_remove callback on classifications to make product dirty so
  # we know to update the customized pricing
  def remove_taxon(taxon)
    self.dirty = true
    removed_classifications = classifications.where(taxon: taxon)
    removed_classifications.each &:remove_from_list
  end


  def avv_related_changes?
    # jobs will be triggered by variants so only checking categories(taxons)
    self.dirty
  end

  def update_viewable_variant_prices
    self.avvs.where('recalculating != ?', Spree::AccountViewableVariant::RecalculatingStatus['enqueued']).update_all(recalculating: Spree::AccountViewableVariant::RecalculatingStatus['backlog'])
    self.variants_including_master.each do |v|
      v.set_viewable_variants
    end
  end

  def update_backorderable_stock_items(backorderable_stock_item_ids)
    self.stock_items.where(id: backorderable_stock_item_ids).update_all(backorderable: true)
    self.stock_items.where.not(id: backorderable_stock_item_ids).update_all(backorderable: false)
  end

  def action #placeholder for bulk actions
  end

  def can_deactivate?
    assemblies_parts = Spree::AssembliesPart.where(part_id: self.variants_including_master.ids)
                                            .includes(:part, :assembly)
    return true if assemblies_parts.blank?

    assemblies_parts.map do |assembly_part|
      self.errors.add(
        :base,
        Spree.t('errors.discontinue_errors.is_part',
                part_name: assembly_part.part.full_display_name,
                assembly_name: assembly_part.assembly.full_display_name)
      )
    end
    false
  end

  def discontinue
    if can_deactivate?
      time = Time.current
      self.update_columns(discontinued_on: time)
      self.variants_including_master.where(discontinued_on: nil).update_all(discontinued_on: time)
      Spree::VendorMailer.discontinued_product_email(self.master).deliver_later
      true
    else
      false
    end
  end

  def make_available
    if self.has_variants?
      unless self.vendor.within_subscription_limit?(
                'products', (self.vendor.showable_variants.active.count + self.variants.count)
              )
        limit = self.vendor.subscription_limit('products')
        self.errors.add(:base, "Your subscription is limited to #{limit} #{'product'.pluralize(limit)}")
        return false
      end
    else
      unless self.vendor.within_subscription_limit?(
                'products', (self.vendor.showable_variants.active.count + 1)
              )
        limit = self.vendor.subscription_limit('products')
        self.errors.add(:base, "Your subscription is limited to #{limit} #{'product'.pluralize(limit)}")
        return false
      end
    end
    time = self.discontinued_on
    self.variants.where(discontinued_on: time).update_all(discontinued_on: nil)
    self.master.update_columns(discontinued_on: nil)
    self.update_columns(discontinued_on: nil, available_on: Time.current)

    true
  end

  def active?
    self.active
  end

  def active
    self.discontinued_on.blank?
  end
  def active=(value)
    val = nil
    val = value.to_bool rescue nil
    if !val && discontinued_on.blank?
      self.should_validate_deactivation = true
      self.discontinue
    elsif val && discontinued_on.present?
      self.make_available
    end
  end

  def has_unsynced_inventory?(integration_key)
    return false unless self.vendor && self.vendor.has_integration?(integration_key)
    relevant_ids = []
    if BUILD_TYPES.has_key?(self.product_type)
      relevant_ids = self.variants_including_master.map do |variant|
        variant.parts.where(variant_type: INVENTORY_TYPES.keys).ids
      end.flatten.uniq
    end
    relevant_ids += self.variants_including_master.where(variant_type: INVENTORY_TYPES.keys).ids

    return false if relevant_ids.empty?
    self.vendor.integration_items.where(integration_key: integration_key).any? do |integration_item|
      integration_item.integration_sync_matches
      .where('integration_syncable_id IN (?) AND integration_syncable_type = ? AND sync_id IS NOT NULL', relevant_ids, 'Spree::Variant').count != relevant_ids.count
    end
  end

  def new_from_master
    master_attrs = self.master.attributes.except('id', 'deleted_at', 'is_master','updated_at', 'stock_items_count')
    var = self.variants.new(master_attrs)
    var.price = self.price

    var
  end

  def self.products_query(options = {})
    query_str = "
    SELECT
      AVG(spree_line_items.price - spree_line_items.price_discount) as avg_price,
      SUM((spree_line_items.price - spree_line_items.price_discount) * spree_line_items.quantity) as revenue,
      SUM(spree_variants.weight * spree_line_items.quantity) as total_weight,
      COUNT(spree_line_items.id) as uniq_purchases,
      sum(spree_line_items.quantity) as quantity,
      spree_line_items.variant_id as variant_id,
      spree_variants.*,
      spree_products.default_display_name as default_display_name,
      spree_line_items.currency
    FROM
      spree_line_items
      JOIN spree_variants ON spree_variants.id = spree_line_items.variant_id
      JOIN spree_products ON spree_products.id = spree_variants.product_id
      JOIN spree_orders ON spree_orders.id = spree_line_items.order_id
    WHERE
      spree_orders.vendor_id = ?
    AND
      spree_orders.state IN (?)"

    query_str += " AND spree_orders.delivery_date >= ? " if options[:delivery_date_gteq]
    query_str += " AND spree_orders.delivery_date <= ? " if options[:delivery_date_lteq]
    query_str += " AND spree_orders.completed_at >= ? " if options[:completed_at_gteq]
    query_str += " AND spree_orders.completed_at <= ? " if options[:completed_at_lteq]
    query_str += " AND spree_orders.approved_at >= ? " if options[:approved_at_gteq]
    query_str += " AND spree_orders.approved_at <= ? " if options[:approved_at_lteq]
    query_str += " AND spree_orders.account_id IN (?) " if options[:account_id]
    query_str += " AND spree_line_items.variant_id IN (?) " if options[:variant_id]

    query_str += "
    GROUP BY
      spree_line_items.variant_id, spree_line_items.currency, spree_variants.id, spree_products.default_display_name
    ORDER BY
      revenue desc
    "

    query_str
  end

  def assign_accounts_from_variant(variant)
    self.assign_attributes({
      income_account_id: variant.income_account_id,
      expense_account_id: variant.expense_account_id,
      cogs_account_id: variant.cogs_account_id,
      asset_account_id: variant.asset_account_id
    })
  end

  def multiple_images?
    images.count > 1
  end

  private

  def set_master_name
    self.master.display_name = self.display_name
  end
  def set_default_display_name
    self.default_display_name = display_name.present? ? display_name : name
  end
  # This is used to set variant attributes based on product attributes in order
  # to simplify the user experience.
  def set_variant_attributes
    self.variants_including_master.update_all(
      tax_category_id: self.tax_category_id,
      variant_type: self.product_type,
      track_inventory: INVENTORY_TYPES.has_key?(self.product_type),
      income_account_id: self.income_account_id,
      expense_account_id: self.expense_account_id,
      cogs_account_id: self.cogs_account_id,
      asset_account_id: self.asset_account_id
    )
  end

  def sku_presence_with_no_variants
    if sku.blank? && !self.has_variants?
      errors.add(:sku, "can't be blank if there are no variants")
      false
    else
      true
    end
  end

  def permitted_product_type_changes
    if product_type_changed? && INVENTORY_TYPES.has_key?(product_type_was) && !INVENTORY_TYPES.has_key?(product_type)
      errors.add(:product_type, "can't change from an Inventory Type to a Non-Inventory Type")
      false
    else
      true
    end
  end

  def sale_or_purchase
    unless self.for_sale || self.for_purchase
      errors.add(:base, "Must select at least one 'buy or sell'")
      false
    else
      true
    end
  end

  def ensure_build_type
    #remove parts for non build type products
    unless BUILD_TYPES.has_key?(self.product_type)
      self.variants_including_master.each(&:remove_parts)
    end
  end

  def reject_option_types(attributes)
    exists = attributes[:id].present?
    no_option_type = attributes[:option_type_id].blank?
    attributes.merge!(_destroy: 1) if exists && no_option_type

    !exists && no_option_type
  end

  def set_variant_fully_qualified_names
    self.variants_including_master.each do |v|
        v.set_fully_qualified_name
    end
  end

end
