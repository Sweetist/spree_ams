class WombatWorker
  include Sidekiq::Worker

  sidekiq_options queue: 'wombat'
  sidekiq_options retry: 0
  sidekiq_options unique: :until_timeout, unique_expiration: 20,
                  unique_args: :unique_args

  def self.unique_args(args)
    object_type = (args[1].keys - ['parameters']).first
    return [] unless object_type
    payload = args[1][object_type]
    [args[0], payload['id'], payload['status'], payload['adjustments']]
  end

  def perform(klass, full_payload)
    assign_class_variables(klass, full_payload)
    result = klass.safe_constantize.new(payload_with_params).result
    update_action(result[:status], result[:message],
                  result[:backtrace], result[:object])
  rescue StandardError => e
    update_action(-1, error_message(e), e.backtrace, object_from_payload, @jid)
    raise
  end

  def assign_class_variables(klass, full_payload)
    @klass = klass
    @full_payload = full_payload.with_indifferent_access
    @payload = full_payload[object_type].with_indifferent_access || {}
  end

  ################################ Shopify integration ##################
  # Find vendor from shopify URL uses when webhooks coming
  def shopify_vendor
    return unless shopify_source
    items = Spree::IntegrationItem.where(integration_key: sync_type)
    selected = items.select { |item| item.shopify_host == shopify_source }
    more_that_one_vendor(shopify_source) if selected.size > 1
    return if selected.blank?
    selected.first.vendor
  end

  # Shopify source(URL)
  def shopify_source
    return unless object_type
    @payload['source']
  end

  # ################### Find objecs from payload: ##########################
  def shipment_object
    return unless @payload['order_id']

    Spree::Order.find_by(number: @payload['order_id'])
  end

  def shipment_vendor
    return unless shipment_object

    shipment_object.vendor
  end
  # #######################################################################

  # Type of coming object like 'order' or 'product'
  def object_type
    return @full_payload.keys.first if @full_payload.keys.first

    raise I18n.t('integrations.object_type_not_found', klass: @klass)
  end

  def object_from_payload
    return unless object_type
    return unless respond_to?("#{object_type}_object")

    send("#{object_type}_object")
  end

  def error_message(error)
    "#{error.message} Payload ID: #{@payload['id']}."
  end

  def vendor
    return vendor_from_params if from_params('vendor')
    return vendor_from_sync_action if vendor_from_sync_action
    return vendor_from_object if vendor_from_object
    return vendor_from_sync_type if vendor_from_sync_type

    vendor_not_found_response
  end

  def vendor_from_params
    Spree::Company.find_by(id: from_params('vendor'))
  end

  def vendor_from_sync_type
    return unless sync_type
    return unless respond_to?("#{sync_type}_vendor")
    send("#{sync_type}_vendor")
  end

  def vendor_from_object
    return unless respond_to?("#{object_type}_vendor")
    send("#{object_type}_vendor")
  end

  def vendor_from_sync_action
    return unless sync_action
    Spree::IntegrationAction.lock(true).find_by(id: sync_action)
                            .try(:vendor)
  end

  def sync_type
    return from_params('sync_type') if from_params('sync_type')

    raise I18n.t('integrations.sync_type_not_found', klass: @klass)
  end

  def sync_action
    Spree::IntegrationAction.find_by(id: from_params('sync_action'))
  end

  def sync_item
    return unless vendor
    sync_item = vendor.integration_items
                      .find_by(integration_key: sync_type)
    return sync_item if sync_item

    no_sync_item_for_vendor_response
  end

  def create_sync_action
    Spree::IntegrationAction
      .create!(integration_item: sync_item,
               execution_log: I18n.t('integrations.queued_in_sidekiq'),
               processed_at: Time.current)
  end

  def payload_with_params
    @payload.merge(parameters: founded_params)
  end

  def founded_params
    {
      vendor: vendor.try(:id),
      sync_type: sync_type,
      sync_action: sync_action.try(:id),
      sync_item: sync_item.try(:id)
    }
  end

  def from_params(attrib)
    @full_payload.with_indifferent_access.dig('parameters', attrib)
  end

  def update_action(status, message, backtrace = nil, integrationable = nil,
                    jid = nil)
    action = sync_action || create_sync_action
    action.update_execution_log(status: status,
                                log: message,
                                backtrace: backtrace,
                                sidekiq_jid: jid,
                                integrationable: integrationable)
  end

  def no_sync_item_for_vendor_response
    raise I18n.t('integrations.no_sync_item_for_vendor',
                 vendor: vendor.name,
                 sync_type: sync_type.camelize)
  end

  def more_that_one_vendor(shopify_source)
    raise I18n.t('integrations.more_than_one_vendor', source: shopify_source)
  end

  def vendor_not_found_response
    raise I18n.t('integrations.vendor_not_found', klass: @klass)
  end
end
