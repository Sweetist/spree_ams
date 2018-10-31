module Spree
  module Integrations
    module ItemSharedAttributes
      extend ActiveSupport::Concern

      INTEGRATIONS_SHARED_ATTRIBUTES = %w[sales_channel
                                          shipping_methods
                                          payment_methods
                                          limit_shipping_method_by
                                          limit_payment_method_by].freeze

      INTEGRATIONS_SHARED_PULL_TYPES = %w[order
                                          credit_memo
                                          account_payment
                                          variant
                                          account].freeze

      INTEGRATIONS_SHARED_ATTRIBUTES.each do |attribute|
        class_eval do
          define_method "#{attribute}=" do |value|
            self.settings = {} unless settings
            settings[attribute] = value
          end
          define_method attribute.to_s do
            return nil unless settings
            settings[attribute]
          end
        end
      end

      INTEGRATIONS_SHARED_PULL_TYPES.each do |type|
        class_eval do
          define_method "#{type}_last_pulled_at" do
            self.settings.fetch('last_pulled_at', {})
                         .fetch("#{type}", nil)
                         .to_datetime rescue nil
          end

          define_method "#{type}_last_pulled_at=" do |value|
            self.settings ||= {}
            self.settings['last_pulled_at'] ||= {}
            self.settings['last_pulled_at']["#{type}"] = value.try(:to_datetime)
          end

          define_method "show_#{type}_last_pulled_at" do
            self.try("#{self.integration_key}_show_#{type}_last_pulled_at") rescue false
          end

          define_method "touch_#{type}_last_pulled_at" do
            self.settings ||= {}
            self.settings['last_pulled_at'] ||= {}
            self.settings['last_pulled_at']["#{type}"] = Time.current
          end

          define_method "#{type}_poll_frequency" do
            self.settings.fetch('poll_frequency', {})
                         .fetch("#{type}", 0)
                         .to_i rescue 0
          end

          define_method "#{type}_poll_frequency=" do |value|
            self.settings ||= {}
            self.settings['poll_frequency'] ||= {}
            self.settings['poll_frequency']["#{type}"] = value.to_i
          end

          define_method "can_poll_#{type}s?" do
            self.try("#{self.integration_key}_can_poll_#{type}s?") rescue false
          end
        end
      end

      def self.shared_params
        params = INTEGRATIONS_SHARED_ATTRIBUTES.map(&:to_sym)
        params += INTEGRATIONS_SHARED_PULL_TYPES.map { |type| "#{type}_last_pulled_at".to_sym }
        params += INTEGRATIONS_SHARED_PULL_TYPES.map { |type| "#{type}_poll_frequency".to_sym }

        params
      end

      def last_pulled_at(object_class)
        self.send("#{object_class.demodulize.underscore}_last_pulled_at") rescue nil
      end

      def polling_frequencies
        [0, 10, 20, 30, 60, 120, 180, 360, 720, 1440]
      end

      def polling_frequencies_for_form
        polling_frequencies.map do |frequency|
          [frequency, display_polling_frequency(frequency)]
        end
      end

      def display_polling_frequency(frequency = 0)
        frequency = frequency.to_i
        if frequency == 0
          I18n.t("integrations.polling_frequency.never")
        elsif frequency < 60
          I18n.t("integrations.polling_frequency.minutes", minutes: frequency)
        elsif frequency == 60
          I18n.t("integrations.polling_frequency.hour")
        else
          I18n.t("integrations.polling_frequency.hours", hours: frequency / 60)
        end
      end
    end
  end
end
