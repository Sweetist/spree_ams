module Spree
  class PriceListAccount < Spree::Base
    belongs_to :account, class_name: 'Spree::Account', foreign_key: :account_id, primary_key: :id
    belongs_to :price_list, class_name: 'Spree::PriceList', foreign_key: :price_list_id, primary_key: :id

    validates :account_id, presence: true

    self.whitelisted_ransackable_attributes = %w[account_id price_list_id]
    self.whitelisted_ransackable_associations = %w[account price_list]
  end
end
