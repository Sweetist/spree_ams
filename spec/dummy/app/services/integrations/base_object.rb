module Integrations
  class Error < StandardError; end
  # base shared class for integration objects
  class BaseObject
    def initialize(data)
      @data = data.with_indifferent_access.freeze
      assign_attributes
      parameters_not_found unless @data[:parameters]
    end

    def result
      result = {}
      result[:object] = spree_object
      result[:message] = @result
      result[:status] = 10
      return result if @result
      raise I18n.t('integrations.please_implement',
                   what: '@result',
                   where: self.class.name)
    end

    private

    def save_result(object, operation)
      @result = I18n.t('integrations.object_received',
                       object_type: object.class.name.demodulize.downcase,
                       operation: operation,
                       number: object.try(:display_number) || object.try(:name),
                       sync_id: sync_id)
    end

    def assign_attributes(data = @data)
      return unless data
      data.each_key do |attribute|
        class_eval do
          define_method attribute do
            @data.dig(attribute)
          end
        end
      end
    end

    def vendor_object
      vendor = Spree::Company.find_by(id: parameters[:vendor])
      return vendor if vendor
      raise Error, I18n.t('integrations.vendor_not_found',
                          klass: self.class.name)
    end

    def raise_errors(errors)
      raise Error, errors.join('. ')
    end

    def sync_id
      return id if @data['id']
      raise Error, I18n.t('integrations.sync_id_not_found',
                          klass: self.class.name)
    end

    def sync_alt_id
      # u can override it for integration
      nil
    end

    def sync_type
      sync_type = parameters.dig('sync_type')
      return sync_type if sync_type
      raise Error, I18n.t('integrations.sync_type_not_found',
                          klass: self.class.name)
    end

    def parent_account_object
      pa = sync_item_object.send("#{sync_type}_parent_account")
      vendor_object.customer_accounts.find_by(id: pa)
    end

    def stock_location_object
      sl = sync_item_object.send("#{sync_type}_stock_location") || vendor_object.stock_locations.first.id
      sl_object = vendor_object.stock_locations.find_by(id: sl)
      return sl_object if sl_object

      raise Error, I18n.t('integrations.not_found_default_stock_location',
                          item: sync_item_object.integration_key)
    end

    def try_find_sync_item_from_vendor
      return unless vendor_object
      vendor_object.integration_items.find_by(integration_key: sync_type)
    end

    def sync_item_object
      item = vendor_object.integration_items.find_by(id: parameters[:sync_item])
      item ||= try_find_sync_item_from_vendor
      return item if item

      raise Error, I18n.t('integrations.sync_item_not_found',
                          klass: self.class.name)
    end

    def update_products?
      return true unless sync_item_object.respond_to?("#{sync_type}_update_products")
      sync_item_object.send("#{sync_type}_update_products")
    end

    def sync_item_overwrite_shipping_cost?
      return true unless sync_item_object
                         .respond_to?("#{sync_type}_overwrite_shipping_cost")

      sync_item_object.send("#{sync_type}_overwrite_shipping_cost")
    end

    def sync_item_shipping_category
      return unless sync_item_object
                    .respond_to?("#{sync_type}_shipping_category")

      category_id = sync_item_object.send("#{sync_type}_shipping_category")
      vendor_object.shipping_categories.find_by(id: category_id)
    end

    def sync_item_shipping_method
      return unless sync_item_object.respond_to?("#{sync_type}_shipping_method")
      sync_item_object.send("#{sync_type}_shipping_method")
    end

    def sync_item_tax_zone
      return unless sync_item_object
                    .respond_to?("#{sync_type}_tax_zone")
      tax_zone = sync_item_object.send("#{sync_type}_tax_zone")
      return vendor_object.zones.find_by(id: tax_zone) if tax_zone
      vendor_object.zones.first
    end

    def sync_item_tax_category
      return unless sync_item_object
                    .respond_to?("#{sync_type}_tax_category")
      category_id = sync_item_object.send("#{sync_type}_tax_category")
      vendor_object.tax_categories.find_by(id: category_id) if category_id
    end

    def find_object_by(sync_id:, sync_type:, klass:)
      integration = sync_item_object
                    .integration_sync_matches
                    .lock
                    .find_by(integration_syncable_type: klass,
                             sync_id: sync_id,
                             sync_type: sync_type)
      integration.integration_syncable if integration.present?
    end

    def parameters_not_found
      raise Error, I18n.t('integrations.parameters_not_found',
                          klass: self.class.name)
    end

    def no_variant_error_for(variant_sku, product_name)
      raise Error,
            I18n.t('integrations.no_variant_with_sku_for_product',
                   sku: variant_sku, product: product_name)
    end

    def process_images(variant, images)
      return if Rails.env.test?
      return unless images.present?
      variant.images.destroy_all

      images.each do |image_hsh|
        variant.images.create!(
          alt: image_hsh['title'],
          attachment: URI.parse(URI.encode(image_hsh['url'].strip)),
          position: image_hsh['position']
        )
      end
    end

    def default_pack_size
      'N/A'
    end

    def critical_data_not_found
      raise Error, I18n.t('integrations.no_critical_data',
                          klass: self.class.name)
    end

    def update_assign_sync_id(object)
      sync_match = object
                   .integration_sync_matches
                   .find_or_create_by!(integration_item: sync_item_object,
                                       sync_type: sync_type)
      sync_match.update!(sync_id: sync_id,
                         synced_at: Time.current,
                         sync_alt_id: sync_alt_id,
                         no_sync: true)
    end

    def create_assign_sync_id(object, param_sync_id = nil)
      object.integration_sync_matches
            .create!(sync_id: param_sync_id || sync_id,
                     integration_item: sync_item_object,
                     sync_type: sync_type,
                     synced_at: Time.current,
                     sync_alt_id: sync_alt_id,
                     no_sync: true)
    end
  end
end
