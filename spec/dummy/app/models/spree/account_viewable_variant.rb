module Spree
  class AccountViewableVariant < Spree::Base
    belongs_to :account, class_name: 'Spree::Account', foreign_key: :account_id, primary_key: :id
    belongs_to :variant, class_name: 'Spree::Variant', foreign_key: :variant_id, primary_key: :id
    belongs_to :price_list, class_name: 'Spree::PriceList', foreign_key: :price_list_id, primary_key: :id
    has_one :vendor, through: :account, source: :vendor
    has_one :customer, through: :account, source: :customer
    has_one :product, through: :variant, source: :product

    scope :visible, -> { where(visible: true) }
    scope :for_sale, -> { joins(variant: :product).where('spree_products.for_sale = ?', true) }

    RecalculatingStatus = {'enqueued' => -1, 'processing' => 0, 'new' => 1, 'backlog' => 2, 'complete' => 10}

    attr_default :visible, false
    attr_default :recalculating, RecalculatingStatus['new']

    self.whitelisted_ransackable_attributes = %w[variant_id account_id price visible]
    self.whitelisted_ransackable_associations = %w[account variant]

    def eligible_promotions
      self.vendor.promotions.where(id: self.promotion_ids)
    end

    def active_eligible_promotions
      self.vendor.promotions.where(id: self.promotion_ids).active
    end

    def active_eligible_advertised_promotions
      self.vendor.promotions.where(id: self.promotion_ids, advertise: true).active
    end

    def account_pricing(account)

    end

    def find_eligible_promotions
      self.promotion_ids = []
      self.vendor.promotions.active.each do |promotion|
        if promotion.is_eligible_discount?(self.account, self.product, self.variant)
          self.promotion_ids << promotion.id unless self.promotion_ids.include?(promotion.id)
        end
      end
      self.save
    end

    def cache_price(promotions = nil)
      self.price = hidden_discount_price(promotions)
      self.recalculating = RecalculatingStatus['complete']
      self.save
    end

    def hidden_discount_price(promotions = nil)
      base_price = price_list_price || variant.price
      return base_price if vendor.use_price_lists && vendor.only_price_list_pricing
      discount_prices = []
      vendor = self.vendor
      promotions ||= vendor.promotions.includes(:promotion_rules, :promotion_actions).active.unadvertised
      promotions.each do |promotion|
        action = promotion.actions.detect{ |action| action.type == "Spree::Promotion::Actions::CreateItemAdjustments" }
        next if action.blank?
        next unless promotion.is_eligible_discount?(self.account, self.product, self.variant)
        calc = action.try(:calculator)
        calc_preferences = calc.try(:preferences)
        if calc_preferences.fetch(:percent, nil)
          discount_prices << (base_price - (calc_preferences[:percent] * base_price * 0.01).round(2))
        elsif calc_preferences.fetch(:amount, nil)
          discount_prices << (base_price - calc_preferences[:amount])
        end
      end

      discount_prices.min || base_price
    end

    def price_list_price(options = {})
      return nil unless variant
      return nil unless vendor.use_price_lists

      variant_price_list = variant.variant_price_lists
        .joins(price_list: :price_list_accounts)
        .where('spree_price_list_accounts.account_id = ?', self.account_id)
        .where('spree_price_lists.active = ?', true)
        .order('spree_price_list_variants.price asc')
        .first

      self.price_list_id = variant_price_list.try(:price_list_id)

      variant_price_list.try(:price)
    end

  end
end
