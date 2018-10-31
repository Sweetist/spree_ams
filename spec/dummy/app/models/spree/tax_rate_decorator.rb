Spree::TaxRate.class_eval do
  include Spree::Integrationable
  clear_validators!
  validates :amount, presence: true, numericality: true
  validates :tax_category_id, presence: true
  validate :included_in_price_default
  self.whitelisted_ransackable_attributes = %w{name amount included_in_price}
  self.whitelisted_ransackable_associations = %w{tax_category zone}

  def self.potential_rates_for_zone(zone, order = nil)
    if order
      order.vendor.tax_rates.select("spree_tax_rates.*, spree_zones.default_tax").
        joins(:zone).
        merge(Spree::Zone.potential_matching_zones(zone, order.vendor_id)).
        order("spree_zones.default_tax DESC")
    else
      []
    end
  end

  def self.match(order_tax_zone, order = nil)
    return [] unless order_tax_zone && order

    potential_rates = potential_rates_for_zone(order_tax_zone, order)
    return potential_rates if potential_rates.empty?
    rates = potential_rates.includes(zone: { zone_members: :zoneable }).load.select do |rate|
      # Why "potentially"?
      # Go see the documentation for that method.
      rate.potentially_applicable?(order_tax_zone)
    end

    # Imagine with me this scenario:
    # You are living in Spain and you have a store which ships to France.
    # Spain is therefore your default tax rate.
    # When you ship to Spain, you want the Spanish rate to apply.
    # When you ship to France, you want the French rate to apply.
    #
    # Normally, Spree would notice that you have two potentially applicable
    # tax rates for one particular item.
    # When you ship to Spain, only the Spanish one will apply.
    # When you ship to France, you'll see a Spanish refund AND a French tax.
    # This little bit of code at the end stops the Spanish refund from appearing.
    #
    # For further discussion, see #4397 and #4327.
    dup_rates = rates
    rates.each do |rate|
      if rate.included_in_price? && (dup_rates - [rate]).map(&:tax_category).include?(rate.tax_category)
        dup_rates -= [rate]
      end
    end

    dup_rates
  end

  def self.adjust(order, items)
    rates = match(order.tax_zone, order)
    tax_categories = rates.map(&:tax_category)
    tax_category_ids = tax_categories.map(&:id)
    relevant_items, non_relevant_items = items.partition { |item| tax_category_ids.include?(item.tax_category_id) }
    Spree::Adjustment.where(adjustable: relevant_items).tax.destroy_all # using destroy_all to ensure adjustment destroy callback fires.
    relevant_items.each do |item|
      relevant_rates = rates.select { |rate| rate.tax_category_id == item.tax_category_id }
      store_pre_tax_amount(item, relevant_rates)
      relevant_rates.each do |rate|
        rate.adjust(order, item)
      end
    end
    non_relevant_items.each do |item|
      if item.adjustments.tax.present?
        item.adjustments.tax.destroy_all # using destroy_all to ensure adjustment destroy callback fires.
        item.update_columns pre_tax_amount: 0
      end
    end
  end

  def potentially_applicable?(order_tax_zone)
    # If the rate's zone matches the order's tax zone, then it's applicable.
    self.zone == order_tax_zone ||
    # If the rate's zone *contains* the order's tax zone, then it's applicable.
    self.zone.contains?(order_tax_zone) ||
    # 1) The rate's zone is the default zone, then it's always applicable.
    (self.included_in_price? && self.zone.default_tax)
  end

  private

  def included_in_price_default
    if self.included_in_price && !Spree::Zone.default_tax(self.tax_category.try(:vendor_id))
      self.errors.add(:included_in_price, Spree.t(:included_price_validation))
      false
    else
      true
    end
  end

end
