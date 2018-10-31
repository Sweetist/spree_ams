module Spree
  module Wombat
    module Handler
      # Handler for touch actions
      class ActionHandler < SweetBase
        def data_klass
          'Integrations::Action'
        end
      end
    end
  end
end
