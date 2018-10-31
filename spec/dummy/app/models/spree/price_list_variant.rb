module Spree
  class PriceListVariant < Spree::Base
    include Spree::Dirtyable
    belongs_to :variant, class_name: 'Spree::Variant',
      foreign_key: :variant_id, primary_key: :id, inverse_of: :variant_price_lists
    belongs_to :price_list, class_name: 'Spree::PriceList',
      foreign_key: :price_list_id, primary_key: :id

    validates :variant_id, presence: true
    validates :price, numericality: { greater_than_or_equal_to: 0 }

    self.whitelisted_ransackable_attributes = %w[variant_id price_list_id price]
    self.whitelisted_ransackable_associations = %w[variant price_list]

  end
end
