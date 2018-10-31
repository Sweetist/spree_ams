require 'active_model_serializers'

module Spree
  module Wombat
    class VariantSerializer < ActiveModel::Serializer
      attributes :sku, :price, :cost_price, :weight, :height, :width, :depth,
                 :inventory_management, :quantity, :option_types,
                 :weight_unit, :sync_id, :is_master
      has_many :images, serializer: Spree::Wombat::ImageSerializer

      def attributes
        super.tap do |hash|
          hash.update(options: options_text)
        end
      end

      def sync_id
        return unless options[:integration_item]

        object.integration_sync_matches
              .find_by(integration_item: options[:integration_item])
              .try(:sync_id)
      end

      def price
        object.price.to_f
      end

      def cost_price
        object.current_cost_price.to_f
      end

      def option_types
        object.product.option_types.where(vendor: object.vendor).pluck(:name)
      end

      def weight_unit
        object.weight_units
      end

      def options_text
        object.option_values.each_with_object({}) { |ov, h| h[ov.option_type.presentation] = ov.presentation }
      end

      def inventory_management
        return false unless options[:stock_location_id]
        return true if INVENTORY_TYPES
                       .key?(object.variant_type)
        false
      end

      def quantity
        return unless options[:stock_location_id]
        return unless INVENTORY_TYPES.key?(object.variant_type)
        stock_item = object.stock_items
                           .find_by(stock_location_id: options[:stock_location_id])
        return unless stock_item
        stock_item.count_on_hand
      end
    end
  end
end
