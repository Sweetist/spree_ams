module Integrations
  module Shopify
    class Product < BaseObject
      include Integrations::Product

      def self.product_data_from_api(shopify_id, vendor)
        product_data = ApiHelper
                       .shopify_product_with(shopify_id, vendor)
        return {} if product_data.blank?
        product_data
      end
    end
  end
end
