module Spree
  module Api
    module Ams
      class OrdersController < Spree::Api::OrdersController
        include Serializable
        include Requestable

        def order_id
          super || params[:id]
        end

        def authorize!(*_args)
          puts 'stub authorize!'
        end
      end
    end
  end
end
