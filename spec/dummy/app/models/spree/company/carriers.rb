module Spree::Company::Carriers
  extend ActiveSupport::Concern

  included do
    CARRIERS_DEFAULTS =
      {
        'ups_login' => '',
        'ups_password' => '',
        'ups_key' => '',
        'ups_valid_credentials' => false,
        'shipper_number' => '',
        'fedex_login' => '',
        'fedex_password' => '',
        'fedex_account' => '',
        'fedex_key' => '',
        'fedex_include_surcharges' => false,
        'fedex_valid_credentials' => false,
        'usps_login' => '',
        'usps_commercial_base' => false,
        'usps_commercial_plus' => false,
        'usps_valid_credentials' => false,
        'units' => 'imperial',
        'unit_multiplier' => 1,
        'default_weight' => 0,
        'handling_fee' => 0,
        'max_weight_per_package' => 0,
        'test_mode' => false
      }.freeze
    attr_default :carriers do
      CARRIERS_DEFAULTS
    end

    CARRIERS_DEFAULTS.each_key do |key|
      define_method key do
        if carriers[key].nil?
          self.respond_to?("#{key}_default") ? self.send("#{key}_default") : CARRIERS_DEFAULTS[key]
        else
          carriers[key]
        end
      end
      define_method "#{key}=" do |value|
        default = CARRIERS_DEFAULTS[key]
        carriers[key] = value if default.is_a?(String)
        carriers[key] = value.to_i if default.is_a?(Integer)
        carriers[key] = value.to_bool if default.is_a?(BooleanToBoolean)
      end
    end
  end
end
