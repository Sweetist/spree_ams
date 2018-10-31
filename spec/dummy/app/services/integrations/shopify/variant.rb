module Integrations
  module Shopify
    class Variant < BaseObject
      include Integrations::Variant

      def self.variant_data_from_api(shopify_parent_id, sku, vendor, parameters)
        product_data = ApiHelper
                       .shopify_product_with(shopify_parent_id, vendor)
        variant_data = product_data['variants'].detect { |v| v['sku'] == sku }
        variant_data['product_id'] =
          Product.new(product_data.merge(parameters: parameters))
                 .spree_object.try(:id)
        return variant_data if variant_data['sku'].present?

        no_variant_error_for(sku, product_data['name'])
      end
    end
  end
end
