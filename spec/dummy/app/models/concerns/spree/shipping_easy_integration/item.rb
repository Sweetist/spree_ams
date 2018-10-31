class CreateConnectionIntegratorError < StandardError; end

module Spree::ShippingEasyIntegration::Item
  extend ActiveSupport::Concern

  SYNC_TYPE = 'shipping_easy'.freeze

  def shipping_easy_callbacks
    {
      before_create: %w[shipping_easy_generate_defaults],
      after_update: %w[shipping_easy_update_connection],
      after_destroy: %w[shipping_easy_destroy_connection]
    }
  end

  def shipping_easy_integration_options
    {
      body:  {
        key: ENV['SWEET_INTEGRATOR_SHIPPING_EASY_KEY'],
        token: ENV['SWEET_INTEGRATOR_SHIPPING_EASY_TOKEN'],
        name: shipping_easy_connection_name,
        url: ENV['SWEET_INTEGRATOR_SHIPPING_EASY_ENDPOINT'],
        parameters: {
          api_key: shipping_easy_api_key,
          api_secret: shipping_easy_api_secret,
          store_api_key: shipping_easy_store_api_key
        }
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'X-Sweet-Integrator-Token' => ENV['SWEET_INTEGRATOR_CONNECTION_TOKEN'],
        'Accept' => 'application/json'
      }
    }
  end

  def shipping_easy_destroy_connection
    HTTParty.delete(ENV['SWEET_INTEGRATOR_CONNECTION_ENPOINT'] + \
        "/#{shipping_easy_connection_name}", shipping_easy_integration_options)
  end

  def shipping_easy_update_connection
    res = HTTParty.patch(ENV['SWEET_INTEGRATOR_CONNECTION_ENPOINT'] + \
        "/#{shipping_easy_connection_name}", shipping_easy_integration_options)

    validate_response(res)
  end

  def shipping_easy_connection_name
    Spree::ShippingEasyIntegration::Item::SYNC_TYPE + '_' + vendor.id.to_s
  end

  # defaults
  def shipping_easy_generate_defaults
    self.order_sync = true
    self.shipping_easy_round = 'round'
  end

  # form fields
  SHIPPING_EASY_HIDDEN_FIELDS = %w[].freeze
  SHIPPING_EASY_FORM_FIELDS = %w[api_key api_secret store_api_key].freeze
  SHIPPING_EASY_SWITCHER_FIELDS = %w[overwrite_shipping_cost].freeze

  (SHIPPING_EASY_HIDDEN_FIELDS \
    + SHIPPING_EASY_FORM_FIELDS).each do |attribute|

    class_eval do
      define_method "shipping_easy_#{attribute}=" do |value|
        self.settings = {} unless self.settings
        self.settings['shipping_easy'] = {} unless self.settings['shipping_easy']
        self.settings['shipping_easy'][attribute] = value
      end
      define_method "shipping_easy_#{attribute}" do
        return '' unless settings && settings['shipping_easy']
        self.settings['shipping_easy'][attribute]
      end
    end
  end

  def shipping_easy_round
    self.settings.fetch('shipping_easy', {}).fetch('round', 'round')
  end

  def shipping_easy_round=(value)
    return unless %w[round floor ceil].include?(value)
    self.settings ||= {}
    self.settings['shipping_easy'] ||= {}
    self.settings['shipping_easy']['round'] = value
  end

  SHIPPING_EASY_SWITCHER_FIELDS.each do |attribute|
    class_eval do
      define_method "shipping_easy_#{attribute}=" do |value|
        self.settings = {} unless self.settings
        self.settings['shipping_easy'] = {} unless self.settings['shipping_easy']
        self.settings['shipping_easy'][attribute] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
      end
      define_method "shipping_easy_#{attribute}" do
        self.settings.fetch('shipping_easy',{}).fetch(attribute, false) rescue false
      end
    end
  end

  def shipping_easy_should_sync_order(order)
    return false unless self.sales_channels_arr.include?(order.channel)
    return true if self.sync_all_shipping_methods?

    if self.whitelist_shipping_methods?
      self.shipping_method_ids.include?(order.shipping_method_id.to_s)
    else
      !self.shipping_method_ids.include?(order.shipping_method_id.to_s)
    end
  end

  def shipping_easy_limit_shipping_methods?
    true
  end

  def shipping_easy_should_sync_variant(variant)
    false
  end

  def validate_response(res)
    return if res.code == 200 || res.code == 201

    raise CreateConnectionIntegratorError, "Push not successful. Sweet \
integrator returned response code #{res.code} and message: #{res.body}"
  end
end
