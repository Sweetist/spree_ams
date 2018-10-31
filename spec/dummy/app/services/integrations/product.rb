module Integrations
  module Product
    def product_data
      return @product_data if @product_data.present?
      product_params = @data.slice(*Spree::Product.attribute_names)
      return nil if product_params.blank?
      product_params.delete('id')
      @product_data = product_params.with_indifferent_access
                                    .merge(additional_data_for_product)
    end

    def variant_by(sku)
      spree_object.variants_including_master.find_by(sku: sku)
    end

    def variants_data
      return @variants_data if @variants_data.present?
      @variants_data = @data['variants']
    end

    def spree_object
      return find_or_create_product if product_data
      raise Error, I18n.t('integrations.no_product_data')
    end

    private

    def synced_object
      find_object_by(sync_id: sync_id,
                     sync_type: sync_type,
                     klass: 'Spree::Product')
    end

    def try_find_by_sku
      skus = variants_data.map { |v| v['sku'] }
      skus << sku
      vendor_object.variants_including_master
                   .where(sku: skus.uniq)
                   .first
                   .try(:product)
    end

    def finded_product
      return @finded_product if @finded_product
      @finded_product = synced_object || try_find_by_sku
    end

    def find_or_create_product
      return non_update_product if finded_product && !update_products?
      return update_product.reload if finded_product && update_products?

      create_product_from_integration.reload
    end

    def remove_pack_size(product)
      product.master.update_columns(pack_size: '')
    end

    def product_should_upgrade_variants?(product)
      return true if variants_data.count > 1 && product.variants.blank?
      false
    end

    # should remove sync_matches because master -> variant
    # if not delete master will finded by sync_matches not sku
    def remove_sync_matches(product)
      product.master.integration_sync_matches.destroy_all
    end

    def handle_variants(product)
      remove_sync_matches(product) if product_should_upgrade_variants?(product)
      variants_data.each do |variant|
        raise_no_variant_sku_error(product) if variant['sku'].blank?
        handle_options = variant_is_master? ? false : true
        "#{self.class.parent}::Variant"
          .constantize.new(variant.merge(parameters: parameters))
          .process_for(product, handle_options)
      end
    end

    def raise_no_variant_sku_error(product)
      raise Error, I18n.t('integrations.no_sku_in_variant',
                          product: product.name)
    end

    def raise_no_product_sku_error(product_name)
      raise Error, I18n.t('integrations.no_sku_in_product',
                          product: product_name)
    end

    def process_associations(product)
      process_product_type(product)
      process_images(product.master, images) if @data['images']
      process_option_types(product) if @data['options']
      assign_sync_sales_channel(product)
      handle_variants(product)
    end

    def non_update_product
      process_option_types(finded_product) if @data['options']
      save_result(finded_product, 'non update in integration settings')
      finded_product
    end

    def update_product
      ActiveRecord::Base.transaction do
        update_assign_sync_id(finded_product)
        finded_product.update!(product_data.except(:pack_size))
        finded_product.reload
        process_associations(finded_product)
        save_result(finded_product, 'updated')
        finded_product
      end
    end

    def create_product_from_integration
      ActiveRecord::Base.transaction do
        product = vendor_object.products.create!(product_data)
        create_assign_sync_id(product)
        remove_pack_size(product)
        process_associations(product)
        save_result(finded_product, 'created')
        product
      end
    end

    def shipping_category_from_settings
      category = sync_item_object.try("#{sync_type}_shipping_category".to_sym)
      vendor_object.shipping_categories.find_by(id: category)
    end

    def default_shipping_category
      return shipping_category_from_settings if shipping_category_from_settings

      shipping_category_name = @data['shipping_category'] || 'Standard'
      vendor_object.shipping_categories
                   .find_by(name: shipping_category_name)
    end

    def tax_category_from_settings
      category = sync_item_object.try("#{sync_type}_tax_category".to_sym)
      vendor_object.tax_categories.find_by(id: category)
    end

    def process_product_type(product)
      return unless inventory_item?
      return if product.is_assembly?
      product.update_columns(product_type: 'inventory_item')
      product.master.update_columns(variant_type: 'inventory_item')
    end

    def additional_data_for_product
      raise_no_product_sku_error(@data['name']) if product_sku.blank?
      {
        sku: product_sku,
        price: master_variant.dig('price'),
        available_on: Date.current,
        shipping_category_id: default_shipping_category.id,
        pack_size: default_pack_size,
        tax_category_id: tax_category_from_settings.id
      }
    end

    def inventory_item?
      inventory_variants = variants_data
                           .select { |v| v['inventory_management'].present? }
      return true if inventory_variants.any?
      false
    end

    def product_sku
      return master_variant.dig('sku') if variant_is_master?
      sku
    end

    def assign_sync_sales_channel(product)
      return unless sync_item_object.sales_channel?
      return if product.sync_to_sales_channels.include?(sync_item_object)
      product.sync_to_sales_channels << sync_item_object
    end

    # ['color', 'size']
    def process_option_types(product)
      return unless options.present?
      return if variant_is_master?

      options.each do |option_type_name|
        option_type = Spree::OptionType.where(name: option_type_name,
                                              vendor: vendor_object)
                                       .first_or_initialize do |option_type|
          option_type.position = options.find_index(option_type_name).to_i + 1
          option_type.presentation = option_type_name
          option_type.vendor = vendor_object
          option_type.save!
        end
        next if product.option_types.include?(option_type)
        product.option_types << option_type
      end
    end

    def variant_is_master?
      return false if variants_data.size > 1
      return true if @data['options'].nil?
      return false if options.first != 'Title' && options.size > 1

      true
    end

    def master_variant
      variants_data.first
    end
  end
end
