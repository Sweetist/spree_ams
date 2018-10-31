module Spree
  class PriceList < Spree::Base
    belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
    belongs_to :customer_type, class_name: 'Spree::CustomerType', foreign_key: :customer_type_id, primary_key: :id
    has_many :price_list_accounts, class_name: 'Spree::PriceListAccount',
      foreign_key: :price_list_id, primary_key: :id, dependent: :destroy
    has_many :price_list_variants, class_name: 'Spree::PriceListVariant',
      foreign_key: :price_list_id, primary_key: :id, dependent: :destroy
    has_many :accounts, through: :price_list_accounts, source: :account
    has_many :variants, through: :price_list_variants, source: :variant
    has_many :spree_account_viewable_variants, class_name: 'Spree::AccountViewableVariant',
      foreign_key: :price_list_id, primary_key: :id
    alias_attribute :avvs, :account_viewable_variants

    self.whitelisted_ransackable_attributes = %w[name vendor_id customer_type_id created_at updated_at active]
    self.whitelisted_ransackable_associations = %w[vendor customer_type price_list_accounts price_list_variants]

    accepts_nested_attributes_for :price_list_variants, allow_destroy: true
    accepts_nested_attributes_for :price_list_accounts, allow_destroy: true

    validates :name, presence: true, uniqueness: { scope: :vendor_id }

    scope :active, (-> { where(active: true) })

    after_destroy { |price_list| price_list.update_avvs }

    def self.adjustment_method_opts
      [
        [Spree.t('price_list.adjustment_method.options.custom'), 'custom'],
        [Spree.t('price_list.adjustment_method.options.flat'), 'flat'],
        [Spree.t('price_list.adjustment_method.options.percent'), 'percent']
      ].freeze
    end

    def self.adjustment_operator_opts
      [
        [Spree.t('price_list.adjustment_operator.options.down'), -1],
        [Spree.t('price_list.adjustment_operator.options.up'), 1]
      ].freeze
    end

    def remove_old_accounts(acc_ids)
      if acc_ids.present?
        self.price_list_accounts.where.not(account_id: acc_ids).delete_all
      else
        self.price_list_accounts.delete_all
      end
    end

    def remove_old_variants(var_ids)
      if var_ids.present?
        self.price_list_variants.where.not(variant_id: var_ids).delete_all
      else
        self.price_list_variants.delete_all
      end
    end

    def select_variants_by_text
      case select_variants_by
      when 'all', 'individual'
        select_variants_by.titleize
      else
        vendor.taxons.find_by_id(select_variants_by).try(:pretty_name)
      end
    end

    def select_customers_by_text
      case select_customers_by
      when 'all', 'individual'
        select_customers_by.titleize
      else
        vendor.customer_types.find_by_id(select_customers_by).try(:name)
      end
    end

    def update_avvs
      Sidekiq::Client.push( 'class' => PriceListAvvWorker,
                            'queue' => 'critical',
                            'args' => [self.id, self.vendor_id] )
    end

  end
end
