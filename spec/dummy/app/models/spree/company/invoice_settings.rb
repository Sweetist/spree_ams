module Spree::Company::InvoiceSettings
  extend ActiveSupport::Concern

  included do
    INVOICE_SETTINGS_DEFAULTS =
      {
        'po_order_next_number' => '00001',
        'po_order_prefix' => 'PO-',
        'next_number' => '0',
        'invoice_prefix' => 'R',                 # :integer, default: nil
        'page_size' => 'LETTER',                 # :string,  default: 'LETTER'
        'page_layout' => 'landscape',            # :string,  default: 'landscape'
        'footer_left' => '',                     # :string,  default: ''
        'footer_right' => '',                    # :string,  default: ''
        'return_message' => '',                  # :text,    default: ''
        'anomaly_message' => '',                 # :text,    default: ''
        'use_footer' => false,                   # :boolean, default: false
        'use_page_numbers' => false,             # :boolean, default: false
        'logo_scale' => 50,                      # :integer, default: 50
        'font_face' => 'Helvetica',              # :string,  default: 'Helvetica'
        'font_size' => 9,                        # :integer, default: 9
        'store_pdf' => false,                    # :boolean, default: false
        'send_invoices' => false,
        'use_po_number' => true,
        'order_next_number' => '0',
        'order_prefix' => 'R',
        'credit_memo_prefix' => 'CR',
        'credit_memo_next_number' => '0',
        'account_payment_prefix' => 'P',
        'account_payment_next_number' => '0',
        'logo_path' => '',
        'include_total_weight' => false,
        'include_unit_weight' => false,
        'po_include_unit_weight' => false,
        'po_include_total_weight' => false,
        'po_pdf_include_unit_weight' => false,
        'po_pdf_include_total_weight' => false,
        'invoice_pdf_include_unit_weight' => false,
        'invoice_pdf_include_total_weight' => false,
        'invoice_pdf_include_balance' => false,
        'weight_units' => 'lb',
        'po_footer_left' => '',
        'po_footer_right' => '',
        'po_pdf_price' => false,
        'bol_terms_and_condtions1' => '',
        'bol_terms_and_condtions2' => '',
        'bol_terms_and_condtions3' => '',
        'bol_require_shipper_signature' => true,
        'bol_require_receiver_signature' => true
      }.freeze
    attr_default :invoice_settings do
      INVOICE_SETTINGS_DEFAULTS
    end

    before_save :gsub_params, if: :invoice_settings_changed?

    after_create do
      invoice_settings['logo_path'] = logo
    end

    def include_total_weight_default
      # 'include_weights' has been split into unit & total weights
      invoice_settings.fetch('include_weights', INVOICE_SETTINGS_DEFAULTS['include_total_weight'])
    end
    def invoice_pdf_total_weight
      # 'include_weights' has been split into unit & total weights
      invoice_settings.fetch('include_weights', INVOICE_SETTINGS_DEFAULTS['invoice_pdf_total_weight'])
    end

    INVOICE_SETTINGS_DEFAULTS.keys.each do |key|
      define_method key do
        if %w[po_order_next_number order_next_number account_payment_next_number credit_memo_next_number next_number].include?(key)
          invoice_settings[key].blank? ? INVOICE_SETTINGS_DEFAULTS[key] : invoice_settings[key]
        else
          if invoice_settings[key].nil?
            self.respond_to?("#{key}_default") ? self.send("#{key}_default") : INVOICE_SETTINGS_DEFAULTS[key]
          else
            invoice_settings[key]
          end
        end
      end
      define_method "#{key}=" do |value|
        default = INVOICE_SETTINGS_DEFAULTS[key]
        if %w[po_order_next_number order_next_number account_payment_next_number credit_memo_next_number next_number].include?(key) && value.blank?
          invoice_settings[key] = default
        else
          invoice_settings[key] = value if default.is_a?(String)
          invoice_settings[key] = value.to_i if default.is_a?(Integer)
          invoice_settings[key] = value.to_bool if default.is_a?(BooleanToBoolean)
        end
      end
    end
  end

  # ########################## INSTANCE METHODS #########################

  def gsub_params
    %w[po_order_next_number order_next_number account_payment_next_number credit_memo_next_number next_number].each do |key|
      next if invoice_settings[key].nil?
      invoice_settings[key].gsub!(/\D/, '')
    end
    %w[invoice_prefix order_prefix account_payment_prefix credit_memo_prefix po_order_prefix].each do |key|
      next if invoice_settings[key].nil?
      invoice_settings[key].gsub!(/[^a-zA-Z0-9\-\_]/, '')
    end
  end
end
