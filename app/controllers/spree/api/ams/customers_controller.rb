module Spree
  module Api
    module Ams
      class CustomersController < Spree::Api::CustomersController
        include Serializable
        include Requestable

        def authorize!(*_args)
          puts 'stub authorize!'
        end
      end
    end
  end
end
