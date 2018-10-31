module Integrations
  module Variant
    def sync_id
      @data.dig('shopify_id')
    end

    def synced_object
      synced_object = find_object_by(sync_id: sync_id,
                                     sync_type: sync_type,
                                     klass: 'Spree::Variant')
      return synced_object if synced_object
      nil
    end

    def find_by_sku
      variant_by_sku = vendor_object.variants_including_master
                                    .find_by(sku: sku)
      return variant_by_sku if variant_by_sku
      nil
    end

    def find_or_new_variant_for(product)
      vendor_object.variants_including_master
                   .where(sku: sku, product: product)
                   .first_or_initialize
    end

    def process_inventory(quantity)
      "#{self.class.parent}::Inventory"
        .constantize.new(product_id: variant.sku,
                         quantity: quantity,
                         parameters: parameters).process!
    end

    def variant_when_product_update_false
      return find_by_sku if find_by_sku

      raise Error, I18n.t('integrations.shopify.no_variant_with_sku_in_sweet',
                          sku: @data['sku'])
      # vendor_object
      #   .variants_including_master
      #   .new(product_id: @data['product_id'] || @product.id,
      #        sku: @data['sku'])
    end

    def variant_when_product_update_true
      return synced_object if synced_object

      find_or_new_variant_for(@product) if @product
    end

    def spree_object
      product = vendor_object.products.find_by(id: @data['product_id'])
      process_for(product) if product

      variant
    end

    def variant
      return @variant if @variant

      @variant = variant_when_product_update_true if update_products?
      @variant = variant_when_product_update_false unless update_products?
      @variant
    end

    # adding variants to the product based on the hash data
    def process_for(product, handle_options = true)
      @product = product
      child_product = @data.slice(*Spree::Variant.attribute_names)
                           .except(:id, :product_id)
      child_product[:price] = price
      child_product[:tax_category_id] = product.tax_category_id
      if handle_options && @data['options']
        child_product[:options] = options
                                  .collect { |k, v| { name: k, value: v } }
      end
      variant.update!(child_product)
      create_assign_sync_id(@variant) if @variant.integration_sync_matches.blank?
      update_assign_sync_id(@variant) if @variant.integration_sync_matches.any?
      process_images(variant, @data.dig('images'))
    end
  end
end
