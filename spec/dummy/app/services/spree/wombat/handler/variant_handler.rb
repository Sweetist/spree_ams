module Spree
  module Wombat
    module Handler
      # Handler for create or update order and contained objects
      class VariantHandler < SweetBase
        def process
          update_parameters

          run_in_queue(data_klass('Variant'), data)
          response nil
        end

        def data
          @payload[:variant].merge(parameters: @parameters)
        end
      end
    end
  end
end
