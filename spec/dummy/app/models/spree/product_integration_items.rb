module Spree
  class ProductIntegrationItems < Spree::Base
    belongs_to :product
    belongs_to :integration_item, foreign_key: :item_id, primary_key: :id
  end
end
