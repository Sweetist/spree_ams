module Spree::QboIntegration::Item
  extend ActiveSupport::Concern
  #
  # Quickbooks Online Integration
  #
  # settings_key: qbo
  #
  # value: {
  #   company,
  #   request_token,
  #   access_token,
  #   group_sync,
  #   match_with_name,
  #   send_as_invoice,
  #   send_po_number
  #   send_discounts
  #   send_shipping
  #   create_related_objects,
  #   qbo_overwrite_conflicts_in,
  #   connected_at
  # }

  def qbo_methods
    {
      authenticate: { title: 'Authenticate', class: 'btn btn-success' },
      callback: { title: 'Callback', class: '' },
      disconnect: { title: 'Disconnect', class: 'btn btn-danger' }
    }
  end

  def qbo_callbacks
    {
      before_create: ['qbo_generate_defaults']
    }
  end

  def qbo_generate_defaults
    self.qbo_match_with_name = true
    self.qbo_send_as_invoice = true
    self.qbo_create_related_objects = true
    self.qbo_enforce_channel = true
    self.qbo_include_department = true
    self.qbo_include_discounts = false
    self.qbo_include_shipping = false
    self.qbo_overwrite_conflicts_in = 'none'
    self.qbo_send_as_non_inventory = false
    self.qbo_track_inventory = false
    self.qbo_track_inventory_from = self.company.stock_locations.first.try(:id)
    self.qbo_bill_from_po = false
    self.order_sync = true
    self.account_sync = true
    self.variant_sync = true
    self.qbo_send_as_bundle = true
    self.qbo_include_lots = self.company.try(:lot_tracking)
    self.qbo_include_assembly_lots = false
    # self.qbo_use_categories = false
  end

  def qbo_queue_name
    begin
      name = "qbo_#{self.company.name.slice(0..10).parameterize.underscore}"
      Sidekiq::Queue[name].limit = 1
      name
    rescue
      'qbo'
    end
  end

  def qbo_should_sync_order(order)
    self.sales_channels_arr.include?(order.channel)
  end

  def qbo_should_sync_purchase_order(channel)
    true
  end

  def qbo_should_sync_variant(variant)
    if variant.try(:is_master) && variant.product.has_variants? && self.qbo_use_categories
      false
    else
      self.variant_sync
    end
  end

  def qbo_should_sync_customer(account)
    case account.try(:channel)
    when 'shopify'
      return false unless self.sales_channel.try(:include?, 'shopify')
      return true unless self.qbo_shopify_use_single_account?
      account.id == self.qbo_shopify_customer_id.to_i
    else
      true
    end
  end

  def qbo_should_sync_payment(payment = nil)
    return false if payment.try(:account_payment).present?
    case limit_payment_method_by
    when 'whitelist'
      payment_method_ids.include?(account_payment.payment_method_id.to_s)
    when 'blacklist'
      !payment_method_ids.include?(account_payment.payment_method_id.to_s)
    else
      true
    end
  end
  def qbo_should_sync_account_payment(account_payment)
    case limit_payment_method_by
    when 'whitelist'
      payment_method_ids.include?(account_payment.payment_method_id.to_s)
    when 'blacklist'
      !payment_method_ids.include?(account_payment.payment_method_id.to_s)
    else
      true
    end
  end

  def qbo_should_sync_inventory(stock_transfer = nil)
    self.qbo_track_inventory
  end

  def qbo_limit_payment_methods?
    true
  end

  # form fields
  def qbo_send_as_bundle
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['send_as_bundle']) rescue false
  end
  def qbo_send_as_bundle=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['send_as_bundle'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_use_categories
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['use_categories']) rescue false
  end
  def qbo_use_categories=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['use_categories'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_bundle_adjustment_account_id
    self.settings['qbo']['bundle_adjustment_account_id'].to_i rescue nil
  end
  def qbo_bundle_adjustment_account_id=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['bundle_adjustment_account_id'] = value.to_i
  end
  def qbo_bundle_adjustment_name
    self.settings['qbo']['bundle_adjustment_name'] rescue ''
  end
  def qbo_bundle_adjustment_name=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['bundle_adjustment_name'] = value
  end
  def qbo_deposit_to_account
    self.settings['qbo']['deposit_to_account'] rescue ''
  end
  def qbo_deposit_to_account=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['deposit_to_account'] = value
  end
  def qbo_company_name
    self.settings['qbo']['company_name'] rescue ''
  end
  def qbo_company_name=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['company_name'] = value
  end
  def qbo_request_token
    self.settings['qbo']['request_token'] rescue ''
  end
  def qbo_request_token=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['request_token'] = value
  end
  def qbo_access_token
    self.settings['qbo']['access_token'] rescue ''
  end
  def qbo_access_token=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['access_token'] = value
  end
  def qbo_request_response
    self.settings['qbo']['request_response'] rescue ''
  end
  def qbo_request_response=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['request_response'] = value
  end
  def qbo_group_sync
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['group_sync']) rescue false
  end
  def qbo_group_sync=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['group_sync'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_match_with_name
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['match_with_name']) rescue false
  end
  def qbo_match_with_name=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['match_with_name'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_send_as_invoice
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['send_as_invoice']) rescue false
  end
  def qbo_send_as_invoice=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['send_as_invoice'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_strip_html
    self.settings['qbo']['strip_html'].to_bool rescue false
  end
  def qbo_strip_html=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['strip_html'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_send_order_as
    qbo_send_as_invoice ? 'Invoice' : 'SalesReceipt'
  end
  def qbo_send_to_line_description
    self.settings.fetch('qbo', {}).fetch('send_to_line_description', 'fully_qualified_description') rescue 'fully_qualified_description'
  end
  def qbo_send_to_line_description=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['send_to_line_description'] = value
  end
  def qbo_custom_field_options
    # Fields here will be called directly from the order hash, so be sure to
    # include_department any additional in the integrationable file.
    [
      ['PO Number', 'po_number'],
      ['Sales Rep', 'rep']
    ]
  end
  def qbo_custom_field_options_display(value)
    qbo_custom_field_options.to_h.key(value)
  end
  def qbo_custom_field_1
    self.settings['qbo']['custom_field_1'] rescue ''
  end
  def qbo_custom_field_1=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['custom_field_1'] = value
  end
  def qbo_custom_field_2
    self.settings['qbo']['custom_field_2'] rescue ''
  end
  def qbo_custom_field_2=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['custom_field_2'] = value
  end
  def qbo_custom_field_3
    self.settings['qbo']['custom_field_3'] rescue ''
  end
  def qbo_custom_field_3=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['custom_field_3'] = value
  end
  def qbo_include_discounts
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['include_discounts']) rescue false
  end
  def qbo_include_discounts=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['include_discounts'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_discount_account_id
    self.settings['qbo']['discount_account_id'].to_i rescue nil
  end
  def qbo_discount_account_id=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['discount_account_id'] = value.to_i
  end
  def qbo_include_shipping
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['include_shipping']) rescue false
  end
  def qbo_include_shipping=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['include_shipping'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_create_related_objects
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['create_related_objects']) rescue false
  end
  def qbo_create_related_objects=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['create_related_objects'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_include_department
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings.fetch('qbo',{}).fetch('include_department', true)) rescue true
  end
  def qbo_include_department=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['include_department'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_enforce_channel
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings.fetch('qbo',{}).fetch('enforce_channel', true)) rescue true
  end
  def qbo_enforce_channel=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['enforce_channel'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_overwrite_conflicts_in
    self.settings['qbo']['overwrite_conflicts_in']
  end
  def qbo_overwrite_conflicts_in=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['overwrite_conflicts_in'] = value
  end
  %w[variant customer vendor].each do |obj|
    class_eval do
      define_method "qbo_#{obj}_overwrite_conflicts_in" do
        self.settings.fetch('qbo', {}).fetch(obj, {}).fetch('overwrite_conflicts_in', qbo_overwrite_conflicts_in) rescue qbo_overwrite_conflicts_in
      end
      define_method "qbo_#{obj}_overwrite_conflicts_in=" do |value|
        self.settings ||= {}
        self.settings['qbo'] ||= {}
        self.settings['qbo'][obj] ||= {}
        self.settings['qbo'][obj]['overwrite_conflicts_in'] = value
      end
    end
  end

  def qbo_include_lots
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['include_lots']) rescue !!self.company.try(:lot_tracking)
  end
  def qbo_include_lots=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['include_lots'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_include_assembly_lots
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['include_assembly_lots']) rescue false
  end
  def qbo_include_assembly_lots=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['include_assembly_lots'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_send_as_non_inventory
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['send_as_non_inventory']) rescue false
  end
  def qbo_send_as_non_inventory=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['send_as_non_inventory'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_track_inventory
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['track_inventory']) rescue false
  end
  def qbo_track_inventory=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['track_inventory'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_track_inventory_from
    self.settings['qbo']['track_inventory_from']
  end
  def qbo_track_inventory_from=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['track_inventory_from'] = value
  end
  def qbo_bill_from_po
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbo']['bill_from_po']) rescue false
  end
  def qbo_bill_from_po=(value)
    self.settings = {} unless self.settings
    self.settings['qbo'] = {} unless self.settings['qbo']
    self.settings['qbo']['bill_from_po'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbo_country
    self.settings.fetch('qbo', {}).fetch('country', 'US') rescue 'US'
  end
  def qbo_country=(value)
    self.settings ||= {}
    self.settings['qbo'] ||= {}
    self.settings['qbo']['country'] = value
  end
  def qbo_multi_currency
    self.settings.fetch('qbo', {}).fetch('multi_currency', false) rescue false
  end
  def qbo_multi_currency=(value)
    self.settings ||= {}
    self.settings['qbo'] ||= {}
    self.settings['qbo']['multi_currency'] = value.to_bool
  end

  def qbo_shopify_customer_id
    self.settings.fetch('qbo', {}).fetch('shopify_customer_id', nil) rescue nil
  end
  def qbo_shopify_customer_id=(value)
    self.settings ||= {}
    self.settings['qbo'] ||= {}
    self.settings['qbo']['shopify_customer_id'] = value
  end
  def qbo_shopify_customer
    return nil if qbo_shopify_customer_id.blank?
    company.customer_accounts.find_by_id(qbo_shopify_customer_id)
  end
  def qbo_shopify_use_single_account?
    qbo_shopify_customer.present?
  end

  def qbo_name
    self.settings.fetch('qbo', {}).fetch('company_name', '')
  end

  def qbo_order_options(order)
    opts = {}
    channel_options = self.method(:qbo_channel_options_for).call(order, order.channel)

    opts.merge(channel_options)
  end

  def qbo_payment_options(payment)
    opts = {}
    channel_options = self.method(:qbo_channel_options_for).call(payment, payment.order.try(:channel))

    opts.merge(channel_options)
  end

  def qbo_channel_options_for(object, channel)
    self.send("qbo_#{channel}_#{object.class.to_s.demodulize.underscore}_options") rescue {}
  end

  def qbo_shopify_order_options
    {customer: qbo_shopify_customer}
  end

  def qbo_shopify_payment_options
    {customer: qbo_shopify_customer}
  end
  # action methods

  def qbo_authenticate(params, integration_url)
    qb_oauth_consumer = OAuth::Consumer.new(
      Rails.application.secrets.qbo_oauth_consumer_key,
      Rails.application.secrets.qbo_oauth_consumer_secret,
      {
        site: 'https://oauth.intuit.com',
        request_token_path: '/oauth/v1/get_request_token',
        authorize_url: 'https://appcenter.intuit.com/Connect/Begin',
        access_token_path: '/oauth/v1/get_access_token'
      }
    )

    request_token = qb_oauth_consumer.get_request_token(oauth_callback: "#{integration_url}/execute?name=callback")

    self.qbo_request_token = Marshal.dump(request_token)
    self.save
    { url: request_token.authorize_url, flash: {} }
  end

  def qbo_callback(params, integration_url)
    self.qbo_request_response = {
      oauth_token: params.fetch('oauth_token', ''),
      oauth_verifier: params.fetch('oauth_verifier', ''),
      realm_id: params.fetch('realmId', ''),
      data_source: params.fetch('dataSource', '')
    }
    request_token = Marshal.load(self.qbo_request_token)
    access_token = request_token.get_access_token(oauth_verifier: self.qbo_request_response.fetch(:oauth_verifier, ''))
    self.qbo_access_token = Marshal.dump(access_token)
    self.save
    qb_company = qbo_service('CompanyInfo')
    company = qb_company.query
    self.qbo_company_name = company.first.try(:company_name)
    self.save

    { url: "#{integration_url}/edit", flash: { success: "QuickBooks Online has been connected." } }
  end

  def qbo_disconnect(params, integration_url)
    self.qbo_service('AccessToken').disconnect
    self.qbo_request_token = nil
    self.qbo_access_token = nil
    self.qbo_request_response = nil
    self.qbo_company_name = ''
    self.save
    { url: "#{integration_url}/edit", flash: { success: "QuickBooks Online has been disconnected." } }
  end

  def qbo_service(type = 'Vendor')
    service = "Quickbooks::Service::#{type}".constantize.new
    service.access_token = Marshal.load(self.qbo_access_token)
    service.company_id = self.qbo_request_response["realm_id"] || self.qbo_request_response[:realm_id]
    service
  end

end
