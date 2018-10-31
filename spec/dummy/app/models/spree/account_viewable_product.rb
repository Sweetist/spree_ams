# == Schema Information
#
# Table name: spree_account_viewable_products
#
#  id              :integer          not null, primary key
#  account_id      :integer          not null
#  product_id      :integer          not null
#  max_price       :decimal(10, 2)
#  min_price       :decimal(10, 2)
#  visible         :boolean          default(FALSE)
#  recalculating   :integer
#  variants_prices :json
#  promotion_ids   :text             default([]), is an Array
#

module Spree
  class AccountViewableProduct < Spree::Base
    belongs_to :account, class_name: 'Spree::Account', foreign_key: :account_id, primary_key: :id
    belongs_to :product, class_name: 'Spree::Product', foreign_key: :product_id, primary_key: :id
    has_one :vendor, through: :account
    has_one :customer, through: :account
    has_many :variants, through: :product
    has_one :master, through: :product
    has_many :variants_including_master, through: :product

    scope :for_sale, -> { joins(:product).where('spree_products.for_sale = ?', true) }
    scope :visible, -> { where(visible: true) }



    attr_default :variants_prices, :default => {}
    attr_default :visible, false
    attr_default :recalculating, Spree::AccountViewableVariant::RecalculatingStatus['new']

    self.whitelisted_ransackable_attributes = %w[product_id account_id]
    self.whitelisted_ransackable_associations = %w[account product]

    def cache_discounted_prices(promotions = nil)
      if self.has_variants?
        product_discount_prices = self.variants.map {|variant| self.variants_prices[variant.id.to_s] = hidden_discount_price(variant.price, variant, promotions)}
      else
        self.variants_prices[self.product.master.id.to_s] = hidden_discount_price(self.product.price, product.master, promotions)
        product_discount_prices = [self.variants_prices[self.product.master.id.to_s]]
      end

      self.min_price = product_discount_prices.min
      self.max_price = product_discount_prices.max
      self.recalculating = Spree::AccountViewableVariant::RecalculatingStatus['complete']
      self.save

      create_or_update_avvs
    end

    def find_eligible_promotions
      self.promotion_ids = []
      self.vendor.promotions.active.each do |promotion|
        self.product.variants_including_master.each do |variant|
          if promotion.is_eligible_discount?(self.account, self.product, variant)
            self.promotion_ids << promotion.id unless self.promotion_ids.include?(promotion.id)
          end
        end
      end
      self.save
    end

    def eligible_promotions
      self.vendor.promotions.where(id: self.promotion_ids)
    end

    def active_eligible_promotions
      self.vendor.promotions.where(id: self.promotion_ids).active
    end

    def active_eligible_advertised_promotions
      self.vendor.promotions.where(id: self.promotion_ids, advertise: true).active
    end

    def has_variants?
      self.variants.present?
    end

    def hidden_discount_price(base_price, variant = nil, promotions = nil)
      return nil if base_price.blank?
      discount_prices = []
      vendor = self.vendor
      promotions ||= vendor.promotions.active.unadvertised
      promotions.each do |promotion|
        action = promotion.actions.where('type = ?', "Spree::Promotion::Actions::CreateItemAdjustments").first
        next if action.blank?
        next unless promotion.is_eligible_discount?(self.account, self.product, variant)
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

    def create_or_update_avvs
      variants_exist = has_variants?
      self.product.variants_including_master.each do |v|
        avv = self.account.account_viewable_variants.find_or_initialize_by(variant_id: v.id)
        if variants_exist && v.is_master?
          avv.visible = false
        else
          avv.visible = self.visible
        end
        price = self.variants_prices.fetch(v.id.to_s, nil)
        if price
          avv.promotion_ids = self.promotion_ids
          avv.price = price
          avv.save
        else
          # will get saved by these methods
          avv.find_eligible_promotions
          avv.cache_price
        end
      end
    end

  end
end
