require 'active_support/configurable'

module Qbd
  module WebConnector
    # Configure global settings for Qbd::WebConnector
    #   Qbd::WebConnector.configure do |config|
    #     config.server_version
    #   end
    def self.configure(&block)
      yield @config ||= Qbd::WebConnector::Configuration.new
    end

    # Global settings for Qbd::WebConnector
    def self.config
      @config
    end

    def self.reset_configuration!
      @config = Qbd::WebConnector::Configuration.new
      set_default_configuration
    end

    def self.set_default_configuration
      configure do |config|
        config.server_version = '1.0.0.alpha'
        config.minimum_web_connector_client_version = nil

        config.parent_controller = 'ApplicationController'

        config.app_name = 'Sweet QBWC App'
        config.app_description = 'Sweet QBWC App Description'
      end
    end

    class Configuration
      include ActiveSupport::Configurable

      config_accessor :server_version
      config_accessor :minimum_web_connector_client_version

      config_accessor :parent_controller

      config_accessor :app_name
      config_accessor :app_description

      def initialize
      end

    end

    set_default_configuration

  end
end
