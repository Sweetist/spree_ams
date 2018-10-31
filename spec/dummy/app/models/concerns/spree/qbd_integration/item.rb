module Spree::QbdIntegration::Item
  require_dependency "#{Rails.root}/lib/integrations/qbd/qbd"

  extend ActiveSupport::Concern
  #
  # Quickbooks Desktop Integration
  #
  # settings_key: qbd
  #
  # value: {
  # }

  def qbd_public_methods
    {
      endpoint: { title: 'Endpoint', class: '' }
    }
  end

  def qbd_methods
    {
      download_qwc: { title: 'Download', class: 'btn btn-info' },
      reset_password: { title: 'Reset Password', class: 'btn btn-danger'}
    }
  end

  def qbd_callbacks
    {
      before_create: ['qbd_generate_defaults']
    }
  end

  def qbd_generate_defaults
    self.qbd_username = self.vendor.name.titleize.tr(' ', '').underscore
    self.qbd_password = SecureRandom.hex(6)
    self.qbd_match_with_name = true
    self.qbd_send_order_as = 'invoice'
    self.qbd_create_related_objects = true
    self.qbd_overwrite_conflicts_in = 'none'
    self.qbd_overwrite_orders_in = 'quickbooks'
    self.qbd_group_discounts = true
    self.qbd_collect_taxes = true
    self.qbd_use_assemblies = true
    self.qbd_use_multi_site_inventory = false
    self.qbd_track_inventory = false
    self.qbd_use_order_class_on_lines = false
    self.qbd_sync_class_on_items_and_customers = false
    self.qbd_track_lots = self.vendor.lot_tracking
    self.qbd_include_assembly_lots = false
    self.qbd_is_to_be_printed = false
    self.qbd_use_external_balance = false
    self.order_sync = true
    self.account_sync = true
    self.variant_sync = true
  end

  def qbd_should_sync_order(order)
    return false if order.state == 'complete' && self.vendor_id == order.vendor_id

    self.sales_channels_arr.include?(order.channel)
  end

  def qbd_should_sync_purchase_order(channel)
    false
  end

  def qbd_should_sync_variant(variant)
    self.variant_sync
  end

  def qbd_should_sync_payment(payment= nil)
    return false if payment.try(:account_payment).present?
    case limit_payment_method_by
    when 'whitelist'
      payment_method_ids.include?(payment.payment_method_id.to_s)
    when 'blacklist'
      !payment_method_ids.include?(payment.payment_method_id.to_s)
    else
      true
    end
  end

  def qbd_should_sync_account_payment(account_payment)
    return false if account_payment.channel == 'qbd'
    case limit_payment_method_by
    when 'whitelist'
      payment_method_ids.include?(account_payment.payment_method_id.to_s)
    when 'blacklist'
      !payment_method_ids.include?(account_payment.payment_method_id.to_s)
    else
      true
    end
  end

  def qbd_should_sync_vendor
    true
  end

  def qbd_should_sync_customer(account)
    case account.try(:channel)
    when 'shopify'
      return false unless self.sales_channel.try(:include?, 'shopify')
      return true unless self.qbd_shopify_use_single_account?
      account == self.qbd_shopify_customer
    else
      true
    end
  end

  def qbd_should_sync_inventory(stock_transfer = nil)
    self.qbd_track_inventory
  end

  def qbd_should_sync_credit_memo(credit_memo)
    true
  end

  def qbd_should_create_object(object_class)
    case object_class.to_s
    when 'Spree::Order', 'Spree::Payment', 'Spree::AccountPayment', 'Spree::CreditMemo'
      true
    else
      self.qbd_create_related_objects
    end
  end

  def qbd_should_update_company?
    true
  end
  def qbd_update_company_settings
    company.use_external_balance = self.qbd_use_external_balance
    company.save
  end

  def qbd_show_order_last_pulled_at
    true
  end
  def qbd_show_credit_memo_last_pulled_at
    true
  end
  def qbd_show_account_payment_last_pulled_at
    true
  end
  def qbd_show_variant_last_pulled_at
    true
  end
  def qbd_show_account_last_pulled_at
    true
  end

  def qbd_can_poll_accounts?
    true
  end
  def qbd_can_poll_orders?
    false
  end
  def qbd_can_poll_account_payments?
    false
  end
  def qbd_can_poll_variants?
    false
  end
  def qbd_can_poll_credit_memos?
    false
  end

  def qbd_can_fetch_products?
    true
  end

  def qbd_can_fetch_customers?
    true
  end

  def qbd_can_fetch_orders?
    true
  end

  def qbd_can_fetch_credit_memos?
    true
  end

  def qbd_can_fetch_account_payments?
    true
  end

  def qbd_filter_by_transaction_date
    true
  end

  def qbd_incomplete_job_message
    I18n.t('integrations.qbd.incomplete_job_message')
  end

  def qbd_item_types
    %w[
        ItemNonInventory ItemInventory ItemOtherCharge ItemService
        ItemAssembly ItemGroup
      ].freeze
  end

  def qbo_limit_payment_methods?
    true
  end

  # form fields

  def qbd_username
    self.settings['qbd']['username'] rescue ''
  end
  def qbd_username=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['username'] = value
  end
  def qbd_password
    self.settings['qbd']['password'] rescue ''
  end
  def qbd_password=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['password'] = value
  end
  def qbd_group_sync
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['group_sync']) rescue false
  end
  def qbd_group_sync=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['group_sync'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_match_with_name
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['match_with_name']) rescue false
  end
  def qbd_match_with_name=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['match_with_name'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_send_as_invoice
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['send_as_invoice']) rescue false
  end
  def qbd_send_order_as
    self.settings.fetch('qbd', {}).fetch('send_order_as') rescue 'invoice'
  end
  def qbd_send_order_as=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['send_order_as'] = value
  end
  def qbd_auto_apply_payment
    self.settings.fetch('qbd', {}).fetch('auto_apply_payment', false) rescue false
  end
  def qbd_auto_apply_payment=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['auto_apply_payment'] = value.to_bool
  end
  def qbd_order_xml_class
    qbd_send_order_as.to_s.camelize
  end
  def qbd_is_to_be_printed
    self.settings['qbd']['is_to_be_printed'].to_bool rescue false
  end
  def qbd_is_to_be_printed=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['is_to_be_printed'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_invoice_template
    self.settings['qbd']['invoice_template'] rescue ''
  end
  def qbd_invoice_template=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['invoice_template'] = value
  end
  def qbd_sales_receipt_template
    self.settings['qbd']['sales_receipt_template'] rescue ''
  end
  def qbd_sales_receipt_template=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['sales_receipt_template'] = value
  end
  def qbd_sales_order_template
    self.settings['qbd']['sales_order_template'] rescue ''
  end
  def qbd_sales_order_template=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['sales_order_template'] = value
  end
  def qbd_credit_memo_template
    self.settings['qbd']['credit_memo_template'] rescue ''
  end
  def qbd_credit_memo_template=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['credit_memo_template'] = value
  end
  def qbd_create_related_objects
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['create_related_objects']) rescue false
  end
  def qbd_create_related_objects=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['create_related_objects'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_update_related_objects
    ActiveRecord::Type::Boolean.new.type_cast_from_database(
      self.settings.fetch('qbd', {}).fetch('update_related_objects', false)
    ) rescue false
  end
  def qbd_update_related_objects=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['update_related_objects'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_overwrite_conflicts_in
    self.settings['qbd']['overwrite_conflicts_in']
  end
  def qbd_overwrite_conflicts_in=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['overwrite_conflicts_in'] = value
  end
  def qbd_overwrite_orders_in
    self.settings['qbd']['overwrite_orders_in'] || 'quickbooks'
  end
  def qbd_overwrite_orders_in=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['overwrite_orders_in'] = value
  end
  def qbd_deposit_to_account
    self.settings['qbd']['deposit_to_account'] rescue ''
  end
  def qbd_deposit_to_account=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['deposit_to_account'] = value
  end
  def qbd_accounts_receivable_account
    self.settings['qbd']['accounts_receivable_account'] rescue ''
  end
  def qbd_accounts_receivable_account=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['accounts_receivable_account'] = value
  end
  def qbd_group_discounts
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['include_discounts']) rescue false
  end
  def qbd_group_discounts=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['include_discounts'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_collect_taxes
    self.settings.fetch('qbd', {}).fetch('collect_taxes', true) rescue true
  end
  def qbd_collect_taxes=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['collect_taxes'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_discount_account_id
    self.settings['qbd']['discount_account_id'].to_i rescue nil
  end
  def qbd_discount_account_id=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['discount_account_id'] = value.to_i
  end
  def qbd_build_assembly_account_id
    self.settings['qbd']['build_assembly_account_id'].to_i rescue nil
  end
  def qbd_build_assembly_account_id=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['build_assembly_account_id'] = value.to_i
  end
  def qbd_discount_item_name
    self.settings['qbd']['discount_item_name'] rescue ''
  end
  def qbd_discount_item_name=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['discount_item_name'] = value
  end
  def qbd_shipping_item_name
    self.settings['qbd']['shipping_item_name'] rescue ''
  end
  def qbd_shipping_item_name=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['shipping_item_name'] = value
  end
  def qbd_use_assemblies
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['use_assemblies']) rescue false
  end
  def qbd_use_assemblies=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['use_assemblies'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_use_multi_site_inventory
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['use_multi_site_inventory']) rescue false
  end
  def qbd_use_multi_site_inventory=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['use_multi_site_inventory'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_track_inventory
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['track_inventory']) rescue false
  end
  def qbd_track_inventory=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['track_inventory'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_use_order_class_on_lines
    self.vendor.track_order_class? && ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['use_order_class_on_lines']) rescue false
  end
  def qbd_use_order_class_on_lines=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['use_order_class_on_lines'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_sync_class_on_items_and_customers
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['sync_class_on_items_and_customers']) rescue false
  end
  def qbd_sync_class_on_items_and_customers=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['sync_class_on_items_and_customers'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_sync_item_class?
    !!(qbd_sync_class_on_items_and_customers && self.vendor.track_line_item_class?)
  end
  def qbd_sync_customer_class?
    !!(qbd_sync_class_on_items_and_customers && self.vendor.track_order_class?)
  end
  def qbd_track_lots
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['track_lots']) rescue !!self.vendor.try(:lot_tracking)
  end
  def qbd_track_lots=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['track_lots'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_include_assembly_lots
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['include_assembly_lots']) rescue false
  end
  def qbd_include_assembly_lots=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['include_assembly_lots'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_bundle_adjustment_account_id
    self.settings['qbd']['bundle_adjustment_account_id'].to_i rescue nil
  end
  def qbd_bundle_adjustment_account_id=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['bundle_adjustment_account_id'] = value.to_i
  end
  def qbd_bundle_adjustment_name
    self.settings['qbd']['bundle_adjustment_name'] rescue ''
  end
  def qbd_bundle_adjustment_name=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['bundle_adjustment_name'] = value
  end
  def qbd_default_shipping_category_id
    self.settings.fetch('qbd', {}).fetch(
      'default_shipping_category_id',
      self.company.shipping_categories.first.try(:id)
    ).to_i rescue nil
  end
  def qbd_default_shipping_category_id=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['default_shipping_category_id'] = value.to_i
  end
  def qbd_line_item_sort
    self.settings.fetch('qbd', {}).fetch('line_item_sort', 'spree_line_items.created_at asc') rescue nil
  end
  def qbd_line_item_sort=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['line_item_sort'] = value.blank? ? nil : value
  end
  def qbd_pull_item_types
    self.settings.fetch('qbd', {}).fetch('pull_item_types', PRODUCT_TYPES.keys) rescue PRODUCT_TYPES.keys
  end
  def qbd_pull_item_types=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['pull_item_types'] = value.blank? ? [] : value
  end
  def qbd_ungroup_grouped_lines
    self.settings.fetch('qbd', {}).fetch('ungroup_grouped_lines', true) rescue true
  end
  def qbd_ungroup_grouped_lines=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['ungroup_grouped_lines'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  def qbd_initial_order_state
    self.settings.fetch('qbd', {}).fetch('initial_order_state', 'invoice') rescue 'invoice'
  end
  def qbd_initial_order_state=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['initial_order_state'] = value
  end
  def qbd_pull_item_types_arr
    qbd_pull_item_types.reject(&:blank?)
  end
  def qbd_pull_order_types
    self.settings.fetch('qbd', {}).fetch('pull_order_types', %w[invoice sales_receipt]) rescue %w[invoice sales_receipt]
  end
  def qbd_pull_order_types=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['pull_order_types'] = value.blank? ? [] : value
  end
  def qbd_pull_order_types_arr
    qbd_pull_order_types.reject(&:blank?)
  end
  def qbd_ignore_items
    self.settings.fetch('qbd', {}).fetch('ignore_items', ['']) rescue ['']
  end
  def qbd_ignore_items=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['ignore_items'] = value.blank? ? [] : value
  end
  def qbd_ignore_items_arr
    qbd_ignore_items.reject(&:blank?)
  end
  def qbd_force_line_position
    self.settings.fetch('qbd', {}).fetch('force_line_position', false) rescue false
  end
  def qbd_force_line_position=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['force_line_position'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_use_external_balance
    self.settings.fetch('qbd', {}).fetch('use_external_balance', false) rescue false
  end
  def qbd_use_external_balance=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['use_external_balance'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def qbd_send_special_instructions_as
    self.settings.fetch('qbd', {}).fetch('send_special_instructions_as', 'memo') rescue 'memo'
  end
  def qbd_send_special_instructions_as=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['send_special_instructions_as'] = value
  end
  def qbd_send_special_instructions_options
    [
      ['Memo (internal note not printed on invoice)', 'memo'],
      ['Line Item (must supply item name to be used in QuickBooks)', 'line_item'],
      ['Do Not Sync', 'none']
    ]
  end
  def qbd_special_instructions_item
    self.settings.fetch('qbd', {}).fetch('special_instructions_item', '') rescue ''
  end
  def qbd_special_instructions_item=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['special_instructions_item'] = value
  end
  def qbd_export_list_to_csv
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['qbd']['export_list_to_csv']) rescue false
  end
  def qbd_export_list_to_csv=(value)
    self.settings = {} unless self.settings
    self.settings['qbd'] = {} unless self.settings['qbd']
    self.settings['qbd']['export_list_to_csv'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  def qbd_name
    self.settings.fetch('qbd', {}).fetch('username', '')
  end

  def qbd_shopify_customer_id
    self.settings.fetch('qbd', {}).fetch('shopify_customer_id', nil) rescue nil
  end
  def qbd_shopify_customer_id=(value)
    self.settings ||= {}
    self.settings['qbd'] ||= {}
    self.settings['qbd']['shopify_customer_id'] = value
  end
  def qbd_shopify_customer
    return nil if qbd_shopify_customer_id.blank?
    company.customer_accounts.find_by_id(qbd_shopify_customer_id)
  end
  def qbd_shopify_use_single_account?
    qbd_shopify_customer.present?
  end

  def qbd_order_options(order)
    opts = { line_item_sort: self.qbd_line_item_sort }
    channel_options = self.method(:qbd_channel_options_for).call(order, order.channel)

    opts.merge(channel_options)
  end

  def qbd_payment_options(payment)
    opts = {}
    channel_options = self.method(:qbd_channel_options_for).call(payment, payment.order.try(:channel))

    opts.merge(channel_options)
  end

  def qbd_channel_options_for(object, channel)
    self.send("qbd_#{channel}_#{object.class.to_s.demodulize.underscore}_options") rescue {}
  end

  def qbd_skip_updates_from_integration(object_class)
    case object_class.to_s
    when 'Spree::Order', 'Spree::Payment', 'Spree::AccountPayment'
      true
    else
      false
    end
  end

  def qbd_shopify_order_options
    {customer: qbd_shopify_customer}
  end

  def qbd_shopify_payment_options
    {customer: qbd_shopify_customer}
  end

  # action methods

  def qbd_endpoint(request, params)
    # QWC will perform a GET to check the certificate, so we gotta respond
    return { xml: { nothing: true }} if request.get?

    response = Qbd::WebConnector::SoapWrapper.route(request, self)
    { xml: response }
  end

  def qbd_download_qwc(params, integration_url)
    case Rails.env
    when "development"
      app_url = "http://localhost:3000/api/integrations/#{self.id}/execute?name=endpoint"
      app_support = "https://support.onsweet.co"
    when "staging"
      app_url = "https://staging.onsweet.co/api/integrations/#{self.id}/execute?name=endpoint"
      app_support = "https://support.onsweet.co"
    when "production"
      app_url = "https://app.onsweet.co/api/integrations/#{self.id}/execute?name=endpoint"
      app_support = "https://support.onsweet.co"
    end
    builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
      xml.QBWCXML {
        xml.AppName            "Sweet Management App"
        xml.AppID              "#{Rails.application.class.parent_name}-#{Time.now.strftime('%Y%m%d%H%M%S')}"
        xml.AppURL              app_url
        xml.AppDescription      ""
        xml.AppSupport          app_support
        xml.UserName            "#{self.qbd_username}"
        xml.OwnerID             "{#{SecureRandom.uuid}}"
        xml.FileID              "{#{SecureRandom.uuid}}"
        xml.QBType              "QBFS"
        xml.Scheduler {
          xml.RunEveryNMinutes 60
        }
        xml.Style              "Document"
        xml.IsReadOnly          false
      }
    end
    { file_data: builder.to_xml, file_name: 'Sweet_QBDesktopSetup.qwc' }
  end

  def qbd_reset_password(params, integration_url)
    self.qbd_password = SecureRandom.hex(6)
    self.save
    self.qbd_create_middleman
    { url: "#{integration_url}/edit", flash: { success: "QuickBooks Desktop password has been updated." } }
  end

end
