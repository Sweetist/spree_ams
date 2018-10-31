module Spree
  module ShopifyIntegration
    module Action
      def shopify_trigger(_integrationable_id,
                          integrationable_type,
                          integration_action)
        case integrationable_type
        when 'Spree::Order'
          push_order_to_wombat
        when 'GetShopifyProducts'
          shopify_get_products
        when 'GetShopifyOrders'
          shopify_get_orders
        when 'Spree::Variant'
          shopify_push_variant_with_inventory
        when 'Spree::Product'
          shopify_push_product_with_inventory
        else
          { status: 11,
            log: I18n.t('integrations.unknown_integrationable_type') }
        end
      end

      # main methods
      def shopify_push_variant_with_inventory
        return update_disabled unless integration_item.shopify_update_products
        return options_error_reponse if integrationable.option_types.count > 3

        push_variant_to_wombat(stock_location: shopify_stock_location_object)
      end

      def shopify_push_product_with_inventory
        return update_disabled unless integration_item.shopify_update_products
        return options_error_reponse if integrationable.option_types.count > 3

        push_product_to_wombat(stock_location: shopify_stock_location_object)
      end

      def shopify_get_products
        object = { requests: [id: 'shopify', query: 'get_products'],
                   parameters: { sync_type: shopify_sync_type,
                                 sweet_push: true },
                   vendor: vendor.id }
        Spree::Wombat::Client.push(object.to_json)
        sent_to_integration_response
      end

      def shopify_get_orders
        object = { requests: [id: 'shopify', query: 'get_orders'],
                   parameters: { sync_type: shopify_sync_type,
                                 since: shopify_last_sync_order,
                                 vendor: vendor.id,
                                 sweet_push: true },
                   vendor: vendor.id }
        Spree::Wombat::Client.push(object.to_json)
        integration_item.shopify_last_sync_order = Time.current
        integration_item.save
        sent_to_integration_response
      end

      private

      def update_disabled
        { status: 10,
          log: I18n.t('integrations.shopify.product_update_disabled') }
      end

      def options_error_reponse
        { status: -1,
          log: I18n.t('integrations.shopify.only_three_options') }
      end

      def shopify_stock_location_object
        integration_item.shopify_stock_location_object
      end

      def shopify_sync_type
        Spree::ShopifyIntegration::Item::SYNC_TYPE
      end

      def shopify_last_sync_order
        integration_item.shopify_last_sync_order || Time.current - 1.month
      end
    end
  end
end
