require 'active_model_serializers'

module Spree
  module Wombat
    class LineItemSerializer < ActiveModel::Serializer
      attributes :id, :product_id, :name, :quantity, :price, :weight_in_ounces

      def weight_in_ounces
        object.variant.weight_in(:oz)
      end

      def product_id
        object.variant.sku
      end

      def price
        object.price.to_f
      end

      def quantity
        return object.quantity.to_f unless options[:round]
        if %w[round floor ceil].include?(options[:round])
          object.quantity.send(options[:round])
        else
          object.quantity.round
        end
      end
    end
  end
end
