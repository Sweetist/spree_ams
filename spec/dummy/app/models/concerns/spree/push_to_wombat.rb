module Spree
  module PushToWombat
    def push_order_to_wombat
      return action.destroy! if integrationable.purchase_order?
      return no_sync_match_response unless integration_sync_match

      Spree::Wombat::Client
        .push_object(integrationable,
                     vendor: vendor.id,
                     parameters: object_params(alternate_sync_id))
      push_to_integration_response(integrationable)
    end

    def push_product_to_wombat(product: integrationable, stock_location: nil)
      Spree::Wombat::Client
        .push_object(product,
                     { vendor: vendor.id,
                       parameters: object_params },
                     stock_location_id: stock_location.try(:id),
                     integration_item: integration_item)
      push_to_integration_response(product)
    end

    def push_variant_to_wombat(variant: integrationable, stock_location: nil)
      Spree::Wombat::Client
        .push_object(variant,
                     { vendor: vendor.id,
                       parameters: object_params },
                     stock_location_id: stock_location.try(:id),
                     integration_item: integration_item)
      push_to_integration_response(variant)
    end

    def push_product_from_variant_to_wombat
      product = integrationable.product
      sync_id = product_sync_id_for(integrationable)
      Spree::Wombat::Client
        .push_object(product,
                     vendor: vendor.id,
                     parameters: object_params(sync_id))
      push_to_integration_response(integrationable)
    end

    def action_sync_type
      integration_item.try(:integration_key)
    end

    def action_sync_id
      integration_sync_match.try(:sync_id)
    end

    def alternate_sync_id
      integration_sync_match.try(:sync_alt_id)
    end

    def product_integration_sync_match_for(variant)
      variant.product.integration_sync_matches
             .find_by(integration_item: integration_item)
    end

    def product_sync_id_for(variant)
      sync_match = product_integration_sync_match_for(variant)
      return sync_match.sync_id if sync_match
    end

    def object_params(local_sync_id = action_sync_id)
      {
        sync_id: local_sync_id,
        sync_type: action_sync_type,
        sync_action: id,
        sweet_push: true,
        vendor: vendor.id
      }
    end

    def object_number(object)
      object.try(:display_number) || object.try(:number)
    end

    def sent_to_integration_response
      { status: 10,
        log: I18n.t('integrations.query_sent_to_integration_app') }
    end

    def no_sync_match_response
      no_sync_id_message = I18n.t('integrations.sync_match_not_found',
                                  klass: object.class.name,
                                  number: object_number)
      { status: -1, log: no_sync_id_message,
        backtrace: no_sync_id_message }
    end

    def action_skipped_response(reason)
      { status: 11, log: I18n.t('integrations.action_skipped',
                                reason: reason) }
    end

    def push_to_integration_response(object)
      { status: 1, log: I18n.t('integrations.object_pushed_to_integration',
                               klass: object.class.name,
                               number: object_number(object)) }
    end
  end
end
