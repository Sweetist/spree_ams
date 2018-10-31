module Integrations
  module Shopify
    # Create class with data from Shopify
    class Order < BaseObject
      include Integrations::Order

      def variant_data_for(line_item)
        shopify_parent_id = line_item['shopify_parent_id']
        sku = line_item['product_id']
        variant_data = Variant.variant_data_from_api(shopify_parent_id,
                                                     sku, vendor_object,
                                                     parameters)

        variant_data.merge(parameters: parameters)
      end

      def product_data_for(line_item)
        shopify_id = line_item['shopify_parent_id']
        product_data = Product.product_data_from_api(shopify_id, vendor_object)
        product_data.merge(parameters: parameters)
      end

      def customer_data
        if shopify_customer_id
          customer_data = ApiHelper
                          .shopify_customer_with({ id: shopify_customer_id },
                                                 vendor_object)
        end
        customer_data ||= ApiHelper.shopify_customer_with({ email: email },
                                                          vendor_object)
        return if customer_data.blank?
        customer_data.merge(parameters: parameters)
      end

      def shopify_customer_id
        @data['customer_id']
      end

      def sync_alt_id
        @data['shopify_id']
      end

      def order_number
        replace_number = id.split('-').last
        "#{vendor_object.order_default_prefix}#{sync_item_object.shopify_order_number_prefix}#{replace_number}"
      end

      def refunds_data
        return @refunds_data if @refunds_data
        @refunds_data = ApiHelper
                        .refunds_for(@data['shopify_id'], vendor_object)
      end

      def handled_refund_data
        refund_line_items = []
        refunds_data.each do |refund|
          refund['refund_line_items'].each do |refund_line_item|
            next unless refund_line_item['line_item'] && refund_line_item['quantity']
            refund_line_items << { sku: refund_line_item['line_item']['sku'],
                                   refund_quantity: refund_line_item['quantity'],
                                   price: refund_line_item['line_item']['price'],
                                   subtotal: refund_line_item['subtotal'],
                                   total_tax: refund_line_item['total_tax'] }
          end
        end
        restock ||= []
        restock = refunds_data.first.dig('restock') if refunds_data.any?
        { refund_line_items: refund_line_items,
          restock: restock }
      end

      def handle_inventory_refunds
        return unless refunds_data
        Refund.new(handled_refund_data.merge(parameters: parameters))
              .process_for(order)
      end
    end
  end
end
