module Spree
  module Wombat
    module Handler
      class Error < StandardError; end
      # Sweet handler base class
      class SweetBase < Base
        def process
          run_in_queue

          response I18n.t('integrations.queued_in_sidekiq')
        end

        def run_in_queue
          WombatWorker.perform_async(data_klass, payload_with_parameters)
        end

        # Spree::Wombat::Handler::ShipmentHandler
        # sync_type = 'shopify'
        # return Integrations::Shopify::Shipment
        def data_klass
          klass_type = self.class.name
                           .gsub!('Spree::Wombat::Handler::', '')
                           .gsub!('Handler', '')
          "Integrations::#{sync_type.camelize}::#{klass_type}"
        end

        def sync_type
          parameters[:sync_type]
        end

        def payload_with_parameters
          payload.merge(parameters: parameters)
        end
      end
    end
  end
end
