module Spree
  module ShippingEasyIntegration
    module Action
      def shipping_easy_trigger(_integrationable_id,
                                integrationable_type,
                                integration_action)
        self.update_columns(status: 1)
        case integrationable_type
        when 'Spree::Order'
          shipping_easy_synchronize_orders(integration_action)
        else
          { status: -1, log: 'Unknown Integrationable Type' }
        end
      end

      def shipping_easy_synchronize_orders(integration_action)
        order = integration_action.company.purchase_orders.find_by_id(integration_action.integrationable_id)
        if order
          integration_action.destroy!
          return
        end
        order = integration_action.company.sales_orders.find_by_id(integration_action.integrationable_id)
        return { status: 10, log: 'Skipped from update after callback' } if order.state == 'shipped'
        return { status: 5, log: 'Order Not Found' } unless order

        sync_match = order.integration_sync_matches
                          .find_or_create_by(sync_type: shipping_easy_sync_type)
        sync_match.update(integration_item: integration_item)
        Spree::Wombat::Client
          .push_object(order,
                       { vendor: order.vendor.id,
                         parameters: {
                           sync_type: shipping_easy_sync_type,
                           sync_id: integration_sync_match.try(:sync_id),
                           sync_action: id,
                           vendor: order.vendor.id,
                           sweet_push: true
                         } },
                       round: integration_item.shipping_easy_round)

        { status: 1, log: 'Order pushed to Integration App' }
      end

      def shipping_easy_sync_type
        Spree::ShippingEasyIntegration::Item::SYNC_TYPE
      end
    end
  end
end
