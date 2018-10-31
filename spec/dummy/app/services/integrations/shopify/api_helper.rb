module Integrations
  module Shopify
    # Singleton helper methods
    module ApiHelper
      class Error < StandardError; end

      class << self
        def shopify_product_with(shopify_id, vendor)
          product = products_from_shopify(vendor, shopify_id)
                    .detect do |pr|
                      pr['shopify_id'].casecmp(shopify_id).zero?
                    end
          return product if product.present?
          raise Error, I18n.t('integrations.no_product_data')
        end

        def shopify_customer_with(data, vendor)
          data.each_key do |key|
            next if data[key].blank?
            customer = customers_from_shopify(vendor, data)
                       .detect do |pr|
                         pr[key.to_s].casecmp(data[key].to_s).zero?
                       end
            return customer if customer.present?
          end
          raise Error, I18n.t('integrations.no_customer_data')
        end

        def payments_for(shopify_id, vendor)
          res = HTTParty.post(ENV['SWEET_INTEGRATOR_SHOPIFY_ENDPOINT'] + '/get_payments', shopify_params(vendor, order_id: shopify_id))
          validate_response(res)
          JSON.parse(res.body)['payments']
        end

        def refunds_for(shopify_id, vendor)
          res = HTTParty.post(ENV['SWEET_INTEGRATOR_SHOPIFY_ENDPOINT'] + '/get_refunds', shopify_params(vendor, order_id: shopify_id))
          validate_response(res)
          JSON.parse(res.body)['refunds']
        end

        private

        def find_intergration_item_by(vendor, sync_type)
          vendor.integration_items.find_by(integration_key: sync_type)
        end

        def shopify_params(vendor, addons)
          integration_item =
            find_intergration_item_by(vendor,
                                      Spree::ShopifyIntegration::Item::SYNC_TYPE)
          {
            body: {
              parameters: {
                shopify_apikey: integration_item.shopify_apikey,
                shopify_password: integration_item.shopify_password,
                shopify_host: integration_item.shopify_host
              }.merge(addons)
            }.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Accept' => 'application/json'
            }
          }
        end

        def products_from_shopify(vendor, shopify_id)
          res = HTTParty.post(ENV['SWEET_INTEGRATOR_SHOPIFY_ENDPOINT'] + '/get_products', shopify_params(vendor, id: shopify_id))
          validate_response(res)
          JSON.parse(res.body)['products']
        end

        def customers_from_shopify(vendor, data)
          res = HTTParty
                .post(ENV['SWEET_INTEGRATOR_SHOPIFY_ENDPOINT'] + '/get_customers',
                      shopify_params(vendor, data))
          validate_response(res)
          JSON.parse(res.body)['customers'] || []
        end

        def validate_response(res)
          return if res.code == 200 || res.code == 201

          raise Error, I18n.t('integrations.net_error_response',
                              code: res.code,
                              body: res.body)
        end
      end
    end
  end
end
