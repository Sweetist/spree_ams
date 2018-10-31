class CreateConnectionIntegratorError < StandardError; end

module Spree::ShopifyIntegration::Item
  extend ActiveSupport::Concern
  SYNC_TYPE = 'shopify'.freeze

  def shopify_methods
    {
      get_products: { title: 'Get products', class: '' },
      get_orders: { title: 'Get orders', class: '' }
    }
  end

  def shopify_get_products(_params, integration_url)
    action = integration_actions
             .create(integrationable_type: 'GetShopifyProducts')
    action.trigger!
    { url: integration_url,
      flash: { success: 'Products was successfully created' } }
  end

  def shopify_get_orders(_params, integration_url)
    action = integration_actions
             .create(integrationable_type: 'GetShopifyOrders')
    action.trigger!

    { url: integration_url,
      flash: { success: 'Orders was successfully queued' } }
  end

  def shopify_callbacks
    {
      before_create: %w[shopify_generate_defaults],
      after_update: %w[shopify_update_connection],
      after_destroy: %w[shopify_destroy_connection]
    }
  end

  def shopify_integration_options
    {
      body:  {
        key: ENV['SWEET_INTEGRATOR_SHOPIFY_KEY'],
        token: ENV['SWEET_INTEGRATOR_SHOPIFY_TOKEN'],
        name: shopify_connection_name,
        url: ENV['SWEET_INTEGRATOR_SHOPIFY_ENDPOINT'],
        parameters: {
          shopify_apikey: shopify_apikey,
          shopify_password: shopify_password,
          shopify_host: shopify_host
        }
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'X-Sweet-Integrator-Token' => ENV['SWEET_INTEGRATOR_CONNECTION_TOKEN'],
        'Accept' => 'application/json'
      }
    }
  end

  def shopify_destroy_connection
    HTTParty.delete(ENV['SWEET_INTEGRATOR_CONNECTION_ENPOINT'] + \
        "/#{shopify_connection_name}", shopify_integration_options)
  end

  def shopify_update_connection
    res = HTTParty.patch(ENV['SWEET_INTEGRATOR_CONNECTION_ENPOINT'] + \
        "/#{shopify_connection_name}", shopify_integration_options)

    validate_response(res)
  end

  def shopify_connection_name
    integration_key + '_' + vendor.id.to_s
  end

  # defaults
  def shopify_shipping_category_object
    vendor.shipping_categories.find_by(id: shopify_shipping_category)
  end

  def shopify_generate_defaults
    self.shopify_last_sync_order = Time.current.beginning_of_month
    self.shopify_stock_location = vendor.default_stock_location.try(:id)
    self.shopify_shipping_category = vendor.shipping_categories.last.try(:id)
    self.shopify_shipping_method = shopify_shipping_category_object
                                   .shipping_methods.last.try(:id)
    self.shopify_tax_category = vendor.tax_categories.last.try(:id)
    self.order_sync = true
    self.variant_sync = false
    self.shopify_update_products = true
  end

  def self.all_settings
    par = SHOPIFY_HIDDEN_FIELDS + SHOPIFY_FORM_FIELDS +
          SHOPIFY_SWITCHER_FIELDS + SHOPIFY_SELECT_FIELDS
    par.map { |p| "#{self::SYNC_TYPE}_#{p}".to_sym }
  end

  # form fields
  SHOPIFY_HIDDEN_FIELDS = %w[last_sync_order].freeze
  SHOPIFY_FORM_FIELDS = %w[apikey password host order_number_prefix].freeze
  SHOPIFY_SWITCHER_FIELDS =
    %w[overwrite_shipping_cost send_automated_emails update_products].freeze
  SHOPIFY_SELECT_FIELDS =
    %w[stock_location parent_account shipping_category
       shipping_method tax_zone tax_category].freeze

  (SHOPIFY_HIDDEN_FIELDS \
    + SHOPIFY_SELECT_FIELDS \
    + SHOPIFY_FORM_FIELDS).each do |attribute|

    class_eval do
      define_method "shopify_#{attribute}=" do |value|
        self.settings = {} unless self.settings
        self.settings['shopify'] = {} unless self.settings['shopify']
        self.settings['shopify'][attribute] = value
      end
      define_method "shopify_#{attribute}" do
        return '' unless settings && settings['shopify']
        self.settings['shopify'][attribute]
      end
    end
  end

  SHOPIFY_SWITCHER_FIELDS.each do |attribute|
    class_eval do
      define_method "shopify_#{attribute}=" do |value|
        self.settings = {} unless self.settings
        self.settings['shopify'] = {} unless self.settings['shopify']
        self.settings['shopify'][attribute] = value.to_bool
      end
      define_method "shopify_#{attribute}" do
        self.settings.fetch('shopify',{}).fetch(attribute, false) rescue false
      end
    end
  end

  def shopify_stock_location_object
    Spree::StockLocation.find_by(id: shopify_stock_location)
  end

  def shopify_should_sync_order(order)
    order.channel == 'shopify'
  end

  def shopify_should_sync_product
    true
  end

  def shopify_should_sync_variant(variant)
    false
  end

  def shopify_should_sync_customer(account)
    account.channel == 'shopify'
  end

  def validate_response(res)
    return if res.code == 200 || res.code == 201

    raise CreateConnectionIntegratorError, "Push not successful. Sweet \
integrator returned response code #{res.code} and message: #{res.body}"
  end
end
