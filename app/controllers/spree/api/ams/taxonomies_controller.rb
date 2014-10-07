module Spree
  module Api
    module Ams
      class TaxonomiesController < Spree::Api::TaxonomiesController
        include Serializable

        private

        def object_serializer
          TaxonomySerializer
        end

      end
    end
  end
end