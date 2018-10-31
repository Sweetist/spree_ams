module Spree
  class CustomerViewableAttribute < Spree::Base
    include Spree::CustomerViewableAttribute::PageSettings
    belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
    belongs_to :banner_image, class_name: 'Spree::BannerImage', foreign_key: :banner_image_id, primary_key: :id

    attr_default :product do
      Spree::Product.column_names.map{|attribute| [attribute, true]}.to_h
    end
    attr_default :variant do
      Spree::Variant.column_names.map{|attribute| [attribute, true]}.to_h
    end
    attr_default :line_item do
      Spree::LineItem.column_names.map{|attribute| [attribute, true]}.to_h
    end
    attr_default :order do
      Spree::Order.column_names.map{|attribute| [attribute, true]}.to_h
    end
    attr_default :invoice do
      Spree::Invoice.column_names.map{|attribute| [attribute, true]}.to_h
    end
    attr_default :account do
      Spree::Account.column_names.map{|attribute| [attribute, true]}.to_h
    end
    attr_default :payment do
      Spree::Payment.column_names.map{|attribute| [attribute, true]}.to_h
    end
    attr_default :standing_line_item do
      Spree::StandingLineItem.column_names.map{|attribute| [attribute, true]}.to_h
    end
    attr_default :standing_order do
      Spree::StandingOrder.column_names.map{|attribute| [attribute, true]}.to_h
    end

    attr_default :theme_name, 'darkblue'
    attr_default :banner_color, '#1b87db'
    attr_default :about_us, ''
    attr_default :announcement, ''
    attr_accessor :pre_header_background_color
    attr_accessor :pre_header_text_color
    attr_accessor :header_background_color
    attr_accessor :header_text_color
    attr_accessor :body_background_color
    attr_accessor :body_text_color
    attr_accessor :button_background_color
    attr_accessor :button_text_color
    attr_accessor :footer_background_color
    attr_accessor :footer_text_color
    attr_accessor :announcement_background_color
    attr_accessor :announcement_text_color
    attr_default :theme_colors do
      { 'pre_header_background' => nil, 'pre_header_text' => nil, 'header_background' => nil, 'header_text' => nil, 'body_background' => nil, 'body_text' => nil, 'button_background' => nil, 'button_text' => nil, 'footer_background' => nil, 'footer_text' => nil, 'announcement_background' => '#ffffff', 'announcement_text' => '#ff0000' }
    end

    def banner_image_url
      banner_image.try(:attachment).try(:url, :xlarge)
    end

    def custom_theme?
      theme_name == 'custom'
    end

    def editable_attr_keys
      attributes.except('announcement', 'announcement_state', 'vendor_id', 'id', "theme_colors", "theme_name", "theme_css", "banner_color", "about_us", "banner_image_id", "pages").keys
    end

    def additional_content_for(key)
      %w[account variant line_item order].include?(key)
    end

    def generate_customer_css(pre_header_background, pre_header_text, header_background, header_text, body_background, body_text, button_background, button_text, footer_background, footer_text, announcement_background, announcement_text)
      @pre_header_background_color = pre_header_background
      @pre_header_text_color = pre_header_text
      @header_background_color = header_background
      @header_text_color = header_text
      @body_background_color = body_background
      @body_text_color = body_text
      @button_background_color = button_background
      @button_text_color = button_text
      @footer_background_color = footer_background
      @footer_text_color = footer_text
      @announcement_background_color = announcement_background
      @announcement_text_color = announcement_text
      template = File.read("#{Rails.root}/app/models/spree/customer_styles.css.erb")
      ERB.new(template).result(binding)
    end

    # SETTERS/GETTERS

    #----------Spree::Variant ---------------
    def variant_lead_time
      self.variant.fetch('lead_time', true)
    end
    def variant_lead_time=(value)
      self.variant ||= {}
      self.variant['lead_time'] = value.to_bool
    end
    def variant_pack_size
      self.variant.fetch('pack_size', true)
    end
    def variant_pack_size=(value)
      self.variant ||= {}
      self.variant['pack_size'] = value.to_bool
    end

    def variant_sku
      self.variant.fetch('sku', true)
    end
    def variant_sku=(value)
      self.variant ||= {}
      self.variant['sku'] = value.to_bool
    end
    def variant_nest_name
      self.variant.fetch('nest_name', true) rescue true
    end
    def variant_nest_name=(value)
      self.variant ||= {}
      self.variant['nest_name'] = value.to_bool
    end
    #----------END Spree::Variant --------------

    #----------Spree::LineItem ---------------
    def line_item_lot_number
      self.line_item.fetch('lot_number', true)
    end
    def line_item_lot_number=(value)
      self.line_item ||= {}
      self.line_item['lot_number'] = value.to_bool
    end

    #----------END Spree::LineItem --------------
    #----------Spree::Order ---------------
    def order_payment_state
      self.order.fetch('payment_state', true)
    end
    def order_payment_state=(value)
      self.order ||= {}
      self.order['payment_state'] = value.to_bool
    end
    def order_backordered_notice
      self.order.fetch('backordered_notice', true)
    end
    def order_backordered_notice=(value)
      self.order ||= {}
      self.order['backordered_notice'] = value.to_bool
    end
    #----------END Spree::Order --------------
    #----------Spree::Invoice ---------------
    def invoice_payment_state
      self.invoice.fetch('payment_state', true)
    end
    def invoice_payment_state=(value)
      self.invoice ||= {}
      self.invoice['payment_state'] = value.to_bool
    end
    #----------END Spree::Invoice --------------
    #----------Spree::Account ---------------
    def account_balance
      self.account.fetch('balance', false)
    end
    def account_balance=(value)
      self.account ||= {}
      self.account['balance'] = value.to_bool
    end
    def account_past_due_balance
      self.account.fetch('past_due_balance', true)
    end
    def account_past_due_balance=(value)
      self.account ||= {}
      self.account['past_due_balance'] = value.to_bool
    end
    def account_spend
      self.account.fetch('spend', false)
    end
    def account_spend=(value)
      self.account ||= {}
      self.account['spend'] = value.to_bool
    end
    #----------END Spree::Account --------------
    #---------- Announcement ---------------
    def announcement_state
      self.product.fetch('announcement_state', false)
    end
    def announcement_state=(value)
      self.product ||= {}
      self.product['announcement_state'] = value.to_bool
    end
    #---------- END Announcement ---------------
  end
end
