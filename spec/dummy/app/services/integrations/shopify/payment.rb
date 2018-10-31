module Integrations
  module Shopify
    class Payment < BaseObject
      include Integrations::Payment

      def payments_data
        return @payments_data if @payments_data
        @payments_data = Integrations::Shopify::ApiHelper
                         .payments_for(@data['order_shopify_id'], vendor_object)
      end
    end
  end
end
