module Spree::SweetistIntegration::Item
  # require_dependency "#{Rails.root}/lib/integrations/sweetist/sweetist"


  extend ActiveSupport::Concern
  #
  # Sweetist Integration
  #
  # settings_key: sweetist
  #
  # value: {
  # }

  def sweetist_public_methods
    {
      order: { title: 'Order', class: '' },
      product: { title: 'Product', class: '' }
    }
  end

  def sweetist_methods
    {
      authenticate: { title: 'Authenticate', class: 'btn btn-success' },
      callback: { title: 'Callback', class: '' },
      disconnect: { title: 'Disconnect', class: 'btn btn-danger' }
    }
  end

  def sweetist_callbacks
    {
      before_create: ['sweetist_generate_defaults'],
      after_update: ['sweetist_update_config']
    }
  end

  def sweetist_generate_defaults
    # self.sweetist_apikey = self.vendor.name.titleize.tr(' ', '').underscore
    self.sweetist_stock_location_id = self.vendor.default_stock_location.try(:id)
    self.sweetist_overwrite_conflicts_in = 'none'
    self.sweetist_send_automated_emails = false
    self.order_sync = true # not supported yet
    self.account_sync = true # not supported yet
    self.variant_sync = true # not supported yet
  end

  def sweetist_should_sync_order(order)
    order.channel == 'sweetist'
  end

  def sweetist_should_sync_variant(variant)
    self.variant_sync? && variant.is_visible_to?(self.sweetist_account)
  end

  def sweetist_account
    self.vendor.customer_accounts.find_by_fully_qualified_name(self.sweetist_account_name)
  end

  # form fields

  def sweetist_access_key
    self.settings['sweetist']['access_key'] rescue ''
  end

  # we will give each bakery a code to enable the integration_actions
  # the format will include a hypen where the last part is the bakery id
  # Ex. access_key = R2002-001, bakery_id = 001 -> 1

  def sweetist_access_key=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['access_key'] = value
  end

  def sweetist_integration_state
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['sweetist']['integration_state']) rescue false
  end

  def sweetist_integration_state=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['integration_state'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  def sweetist_send_automated_emails
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['sweetist']['send_automated_emails']) rescue false
  end

  def sweetist_send_automated_emails=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['send_automated_emails'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  def sweetist_account_name
    self.settings['sweetist']['account_name'] rescue ''
  end

  def sweetist_account_name=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['account_name'] = value
  end

  def sweetist_weight_units
    self.settings['sweetist']['weight_units'] rescue ''
  end
  def sweetist_weight_units=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['weight_units'] = value
  end

  def sweetist_dimension_units
    self.settings['sweetist']['dimension_units'] rescue ''
  end
  def sweetist_dimension_units=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['dimension_units'] = value
  end

  def sweetist_stock_location_id
    self.settings['sweetist']['stock_location_id'] rescue nil
  end
  def sweetist_stock_location_id=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['stock_location_id'] = value
  end
  def sweetist_overwrite_conflicts_in
    self.settings['sweetist']['overwrite_conflicts_in']
  end
  def sweetist_overwrite_conflicts_in=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['overwrite_conflicts_in'] = value
  end

  def sweetist_bakery_id
    self.sweetist_access_key.to_s.split('-').last.to_i
  end

  ################# BAKERY SETTINGS ############################################

  def sweetist_min_order_reqmt
    self.settings['sweetist']['min_order_reqmt']
  end
  def sweetist_min_order_reqmt=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['min_order_reqmt'] = value.to_i  #probably want to change this to decimal
  end
  def sweetist_email
    self.settings['sweetist']['email']
  end
  def sweetist_email=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['email'] = value
  end
  def sweetist_phone
    self.settings['sweetist']['phone']
  end
  def sweetist_phone=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['phone'] = value
  end
  def sweetist_address
    self.settings['sweetist']['address']
  end
  def sweetist_address=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['address'] = value
  end
  def sweetist_city
    self.settings['sweetist']['city']
  end
  def sweetist_city=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['city'] = value
  end
  def sweetist_zipcode
    self.settings['sweetist']['zipcode']
  end
  def sweetist_zipcode=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['zipcode'] = value
  end
  def sweetist_state
    self.settings['sweetist']['state']
  end
  def sweetist_state=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['state'] = 'New York'
  end
  def sweetist_country
    self.settings['sweetist']['country']
  end
  def sweetist_country=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['country'] = 'United States'
  end

  #---------- HOURS OF OPERATION -------#
  def sweetist_open_su
    self.settings.fetch('sweetist', {}).fetch('open_su', nil)
  end
  def sweetist_open_su=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['open_su'] = value
  end
  def sweetist_open_mo
    self.settings.fetch('sweetist', {}).fetch('open_mo', nil)
  end
  def sweetist_open_mo=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['open_mo'] = value
  end
  def sweetist_open_tu
    self.settings.fetch('sweetist', {}).fetch('open_tu', nil)
  end
  def sweetist_open_tu=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['open_tu'] = value
  end
  def sweetist_open_we
    self.settings.fetch('sweetist', {}).fetch('open_we', nil)
  end
  def sweetist_open_we=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['open_we'] = value
  end
  def sweetist_open_th
    self.settings.fetch('sweetist', {}).fetch('open_th', nil)
  end
  def sweetist_open_th=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['open_th'] = value
  end
  def sweetist_open_fr
    self.settings.fetch('sweetist', {}).fetch('open_fr', nil)
  end
  def sweetist_open_fr=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['open_fr'] = value
  end
  def sweetist_open_sa
    self.settings.fetch('sweetist', {}).fetch('open_sa', nil)
  end
  def sweetist_open_sa=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['open_sa'] = value
  end

  def sweetist_closed_su
    self.settings.fetch('sweetist', {}).fetch('closed_su', nil)
  end
  def sweetist_closed_su=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['closed_su'] = value
  end
  def sweetist_closed_mo
    self.settings.fetch('sweetist', {}).fetch('closed_mo', nil)
  end
  def sweetist_closed_mo=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['closed_mo'] = value
  end
  def sweetist_closed_tu
    self.settings.fetch('sweetist', {}).fetch('closed_tu', nil)
  end
  def sweetist_closed_tu=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['closed_tu'] = value
  end
  def sweetist_closed_we
    self.settings.fetch('sweetist', {}).fetch('closed_we', nil)
  end
  def sweetist_closed_we=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['closed_we'] = value
  end
  def sweetist_closed_th
    self.settings.fetch('sweetist', {}).fetch('closed_th', nil)
  end
  def sweetist_closed_th=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['closed_th'] = value
  end
  def sweetist_closed_fr
    self.settings.fetch('sweetist', {}).fetch('closed_fr', nil)
  end
  def sweetist_closed_fr=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['closed_fr'] = value
  end
  def sweetist_closed_sa
    self.settings.fetch('sweetist', {}).fetch('closed_sa', nil)
  end
  def sweetist_closed_sa=(value)
    self.settings ||= {}
    self.settings['sweetist'] ||= {}
    self.settings['sweetist']['closed_sa'] = value
  end

  #---------- END HOURS OF OPERATION ------------#

  def sweetist_bakery_hash
    {
      bakery: {
        sweet_integration_num: self.id,
        min_order_reqmt: self.sweetist_min_order_reqmt,
        email: self.sweetist_email,
        phone: self.sweetist_phone,
        address: self.sweetist_address,
        city: self.sweetist_city,
        zipcode: self.sweetist_zipcode,
        # state: self.sweetist_state,
        # country: self.sweetist_country,
        open_su: self.sweetist_open_su,
        open_mo: self.sweetist_open_mo,
        open_tu: self.sweetist_open_tu,
        open_we: self.sweetist_open_we,
        open_th: self.sweetist_open_th,
        open_fr: self.sweetist_open_fr,
        open_sa: self.sweetist_open_sa,
        closed_su: self.sweetist_closed_su,
        closed_mo: self.sweetist_closed_mo,
        closed_tu: self.sweetist_closed_tu,
        closed_we: self.sweetist_closed_we,
        closed_th: self.sweetist_closed_th,
        closed_fr: self.sweetist_closed_fr,
        closed_sa: self.sweetist_closed_sa

      }.delete_if{|k,v| v.blank?}
    }
  end
  ##################### END BAKERY SETTINGS ####################################


  def sweetist_update_config
    Sidekiq::Client.push('class' => SweetistSyncWorker, 'queue' => 'integrations', 'args' => [self.class.to_s, self.id])
  end

  # action methods

  def sweetist_order(request, params)

    # limiting to POST request
    return 501 unless request.method == "POST"

    action = self.integration_actions.create(integrationable_type: 'Sweetist::Order')
    action.trigger!
    response, status, error = sweetist_order_sync(request.body.string)
    if error.present?
      action.update_columns(status: -2, execution_log: "#{action.execution_log} #{response.fetch(:number, nil) || response.fetch('number', nil)}:, #{error}")
    else
      action.update_columns(status: 10, execution_log: "#{action.execution_log} #{response.fetch(:number, nil) || response.fetch('number', nil)}")
    end

    { json: response }
  end

  def sweetist_product(request, params)
    return 501 unless request.method == "POST"
    product_request = JSON.parse(request.body.string)
    response = sweetist_sync_product(product_request)
    { json: response }
  end

  private

  def sweetist_sync_product(product_request) #DONE
    # SYNC ASSOCIATED OBJECTS FIRST
    tax_category_id = sweetist_tax_category_sync(product_request.fetch('tax_category', {})).try(:id)
    shipping_category_id = sweetist_shipping_category_sync(product_request.fetch('shipping_category', {})).try(:id)
    option_type_ids = sweetist_option_type_sync(product_request['option_types']).map{|ot| ot.id}
    # BUILD PRODUCT AND VARIANT HASHES
    product_hash = sweetist_map_to_sweet_obj(product_request, 'Spree::Product')
    product_hash['tax_category_id'] = tax_category_id
    product_hash['shipping_category_id'] = shipping_category_id
    product_hash['option_type_ids'] = option_type_ids

    master_hash = sweetist_map_to_sweet_obj(product_request.fetch('master',{}), 'Spree::Variant')
    master_hash['tax_category_id'] = tax_category_id

    variants_array = product_request.fetch('variants', {}).map do |v_hash|
      variant_hash = sweetist_map_to_sweet_obj(v_hash, 'Spree::Variant')
      variant_hash['tax_category_id'] = tax_category_id
      variant_hash
    end

    # FIND OR CREATE MATCH TO MASTER VARIANT
    master_match = self.integration_sync_matches.find_or_create_by(
      sync_id: master_hash['id'],
      integration_syncable_type: 'Spree::Variant'
    )

    # FIND MASTER VARIANT IF MATCH EXISTS
    master = self.vendor.variants_including_master.find_by_id(master_match.integration_syncable_id)
    # FIND PRODUCT BY MASTER IF MATCH WAS FOUND, OTHERWISE FIND BY NAME
    product = master.try(:product) || self.vendor.products.where(name: product_hash.fetch('name', nil)).first

    if product.present?
      # DEFINE MASTER IF THE MATCH WAS NOT FOUND
      master ||= product.master
      if variants_array.present?
        variants_array.each do |variant_hash|
          variant_match = self.integration_sync_matches.find_or_create_by(
            sync_id: variant_hash['id'],
            integration_syncable_type: 'Spree::Variant'
          )
          # FIND VARIANT BY SYNC MATCH OR BY SKU
          variant = product.variants.find_by_id(variant_match.integration_syncable_id) || product.variants.find_by_sku(variant_hash.fetch('sku', nil))
          if variant.present?
            variant.update(variant_hash.except('id','product_id','prices','option_values'))
          else
            variant_hash['weight_units'] = self.sweetist_weight_units
            variant_hash['dimension_units'] = self.sweetist_dimension_units
            variant = product.variants.create(variant_hash.except('id','product_id','prices','option_values'))
          end
          variant_match.update_columns(integration_syncable_id: variant.try(:id))
        end
      end

      # TODO make sure calling update does not trigger a loop of callbacks
      master.update(master_hash.except('id','product_id','prices','option_values'))
      product.update(product_hash.except('id'))
    else
      # NEW PRODUCT
      master_hash['weight_units'] = self.sweetist_weight_units
      master_hash['dimension_units'] = self.sweetist_dimension_units

      product_hash['master_attributes'] = master_hash.except('id','product_id','prices','option_values')
      product = self.vendor.products.new(product_hash.except('id'))

      variants_array.each do |variant_hash|
        variant_hash['weight_units'] = self.sweetist_weight_units
        variant_hash['dimension_units'] = self.sweetist_dimension_units
        variant = product.variants.new(variant_hash.except('id','product_id','prices','option_values'))
        variant.integration_sync_matches.new(
          sync_id: variant_hash['id'],
          integration_syncable_type: 'Spree::Variant',
          integration_item_id: self.id
        )
      end

      product.save
    end
    master_match.update_columns(integration_syncable_id: product.master.id)
  end

  def sweetist_order_sync(order_hash_str)
    # parsing request body to a hash
    errors = []
    begin
      order_response = JSON.parse order_hash_str
      order_match = self.integration_sync_matches.find_or_create_by(
        sync_id: order_response['id'],
        integration_syncable_type: "Spree::Order"
      )

      line_items_hash = order_response['line_items']
      bakery_company_hash = order_response['bakery']
      shipments_hash = order_response['shipments']
      bill_address_hash = order_response['bill_address']
      ship_address_hash = order_response['ship_address']
      user_hash = order_response['user']

      sweet_order_hash = sweetist_map_to_sweet_obj(
        order_response.except('line_items', 'bakery', 'shipments', 'bill_address', 'ship_address', 'bakery_id', 'user'),
        'Spree::Order'
      )

      puts 'Sweet Order Hash'
      puts sweet_order_hash
      # sweet_order_hash = order_response.except('id', 'fulfillment_type', 'fulfillment_date', 'fulfillment_time', 'tip',
      #   'fulfillment_time_window', 'ship_date', 'is_gift', 'gift_note', 'senders_mobile', 'default_option', 'service_fee',
      #   'invoice_number', 'invoice_date', 'line_items', 'bakery', 'shipments', 'bill_address', 'ship_address', 'bakery_id', 'user')
      sweet_order_hash['delivery_date'] = order_response['ship_date']
      sweet_order_hash['is_delivery?'] = order_response['fulfillment_type'] == 'delivery' ? true : false
      sweet_order_hash['approved'] = order_response.fetch('approved_at', nil).present?
      sweet_order_hash['vendor_id'] = self.vendor_id
      # sweet_order_hash['channel'] = 'Sweetist'

      # for sweetist, the account is the vendor's brick and mortar location working with sweetist
      # and therefore needs to be set up manually prior to the integration and selected in the integration sweetist_updated_item
      account = self.sweetist_account
      sweet_order_hash['account_id'] = account.id
      # sweet_order_hash['customer_id'] # customer_id on an order is obsolete

      # sync order bill address, ship address, user
      sweet_order_hash['bill_address_id'] = sweetist_address_sync(bill_address_hash, 'billing').try(:id)
      sweet_order_hash['ship_address_id'] = sweetist_address_sync(ship_address_hash, 'shipping').try(:id)
      puts 'SYNCING USER'
      sweet_order_hash['user_id'] = sweetist_user_sync(user_hash).try(:id)

      order = self.vendor.sales_orders.find_by_id(order_match.integration_syncable_id)
      order ||= self.vendor.sales_orders.find_by_number(sweet_order_hash.fetch('number', nil))

      if order
        puts ''
        puts 'FOUND ORDER BY SYNC MATCH OR NUMBER'
        puts ''

        if sweet_order_hash.fetch('state') == 'approved' && Spree::Order::States[order.state] >= Spree::Order::States['approved']
          sweet_order_hash.delete('state') == 'shipped'
        end
        service_fee = sweet_order_hash.fetch('custom_attrs', {}).fetch('sweetist', {}).fetch('service_fee', 0).to_d
        service_adjustment = order.adjustments.find_by(label: 'Service Fee')
        if service_adjustment.present?
          service_adjustment.update(amount: service_fee)
        else
          order.adjustments.create!(label: 'Service Fee', amount: service_fee, order: order)
        end

        order.update(sweet_order_hash)
        line_items = []
        line_items_hash.each do |li_hash|
          line_items << sweetist_line_item_sync(order, li_hash)
        end
        order.line_items.where.not(id: line_items.map{|item| item.id}.compact).destroy_all


        puts 'BEGIN SYNC SHIPMENT'
        shipment = sweetist_shipment_sync(order, shipments_hash.first)
        puts 'FINISH BUILDING SHIPMENT'

        shipment_match = self.integration_sync_matches.find_or_create_by(
          sync_id: shipments_hash.first.fetch('id',nil),
          integration_syncable_type: "Spree::Shipment"
        )
        # sync shipping method
        shipping_method = sweetist_shipping_method_sync(order, shipments_hash.first['shipping_method'])
        order.shipping_method_id = shipping_method.try(:id)
        order.override_shipment_cost = true
        order.save!
        shipment.save!
        shipment_match.update_columns(integration_syncable_id: shipment.id)
        if order.state == 'approved' && order.shipment_state == 'shipped'
          order.next!
        end
        [
          order.to_integration(
              self.integration_item.integrationable_options_for(order)
            ),
          200,
          nil
        ]
      else
        puts ''
        puts 'START A NEW ORDER'
        puts ''
        order = self.vendor.sales_orders.new(sweet_order_hash)
        service_fee = sweet_order_hash.fetch('custom_attrs', {}).fetch('sweetist', {}).fetch('service_fee', 0).to_d
        line_items_hash.each do |li_hash|
          sweetist_line_item_sync(order, li_hash)
        end
        puts 'BEGIN SHIPMENT'
        shipment = sweetist_shipment_sync(order, shipments_hash.first)
        puts 'END SHIPMENT'
        shipment_match = self.integration_sync_matches.find_or_create_by(
          sync_id: shipments_hash.first.fetch('id',nil),
          integration_syncable_type: "Spree::Shipment"
        )
        # sync shipping method
        shipping_method = sweetist_shipping_method_sync(order, shipments_hash.first['shipping_method'])

        order.shipping_method_id = shipping_method.try(:id)
        order.override_shipment_cost = true
        puts "ORDER ERRORS: #{order.errors.full_messages}"
        order.save!
        puts "ORDER SAVED: #{order.persisted?.to_s.upcase}"
        puts "SHIPMENT ERRORS: #{shipment.errors.full_messages}"
        shipment.save!
        puts "SHIPMENT SAVED: #{shipment.persisted?.to_s.upcase}"
        if service_fee > 0.0
          order.adjustments.create!(label: 'Service Fee', amount: service_fee, order: order)
        end
        shipment_match.update_columns(integration_syncable_id: shipment.id)
        order_match.update_columns(integration_syncable_id: order.id)
        if order.state == 'approved' && order.shipment_state == 'shipped'
          order.next!
        end
        [
          order.to_integration(
              self.integration_item.integrationable_options_for(order)
            ),
          201,
          nil
        ]
      end

    rescue Exception => e
      order_response ||= {}
      [order_response, 500, e.message]
    end
  end


  def sweetist_line_item_sync(order, line_item_hash)
    puts ''
    puts 'SYNC LINE ITEM'
    puts ''
    product_request = line_item_hash.fetch('variant',{}).fetch('product',{})
    variant_hash = line_item_hash['variant'].except('product', 'product_id', 'dietary_info', 'num_servings', 'fragile', 'max_order_qty')

    sweetist_sync_product(product_request)
    variant_match = self.integration_sync_matches.find_or_create_by(
      sync_id: variant_hash['id'],
      integration_syncable_type: "Spree::Variant"
    )
    variant_to_add = self.vendor.variants_including_master.find_by_id(variant_match.integration_syncable_id)

    line_item_match = self.integration_sync_matches.find_by(
      sync_id: line_item_hash['id'],
      integration_syncable_type: "Spree::LineItem"
    )
    if line_item_match.try(:integration_syncable_id)
      puts "FOUND LINE ITEM WITH ID #{line_item_match.try(:integration_syncable_id)}"
      line_item = order.line_items.find_by_id(line_item_match.integration_syncable_id)
      line_item_attrs = sweetist_map_to_sweet_obj(line_item_hash.except('order_id', 'variant_id'), 'Spree::LineItem')
      line_item_attrs['ordered_qty'] = line_item_attrs.fetch('quantity','')
      line_item_attrs['shipped_qty'] = line_item_attrs.fetch('quantity','')
      line_item.update(line_item_attrs)
    else
      puts ""
      puts "BUILD NEW LINE ITEM"
      puts ''
      line_item = order.line_items.new(
        quantity: line_item_hash['quantity'],
        ordered_qty: line_item_hash['quantity'],
        variant: variant_to_add,
        item_name: variant_to_add.fully_qualified_name
        #options: opts
      )
      line_item.integration_sync_matches.new(
        sync_id: line_item_hash['id'],
        integration_syncable_type: "Spree::LineItem",
        integration_item_id: self.id
      )
    end
    puts "LINE ITEM ERRORS: #{line_item.errors.full_messages}"
    line_item
  end

  def sweetist_tax_rate_sync
    # TODO tax rate sync
    # sync zone to NY STATE
    # rate to MANAHATTAN
  end

  def sweetist_shipment_sync(order, shipment_hash)
    shipment_match = self.integration_sync_matches.find_or_create_by(
      sync_id: shipment_hash['id'],
      integration_syncable_type: "Spree::Shipment"
    )
    shipment_hash['shipping_method_id'] = sweetist_shipping_method_sync(order, shipment_hash['shipping_method']).try(:id)
    shipment_hash['stock_location_id'] = sweetist_stock_location_sync.try(:id) #no need to send any params for this method
    shipment_attrs = sweetist_map_to_sweet_obj(shipment_hash.except('order_id'), 'Spree::Shipment')
    shipment = Spree::Shipment.find_by_id(shipment_match.integration_syncable_id)
    shipment ||= order.try(:shipments).try(:first)
    if shipment
      shipment.update(shipment_attrs)
    else
      shipment_hash = shipment_hash.except('id', 'delivery_time_window', 'deleted_at', 'created_at', 'updated_at', 'stock_location', 'stock_location_id')
      shipment_hash['address_id'] = order.ship_address_id

      shipping_method = order.try(:shipping_method)

      shipping_method ||= sweetist_shipping_method_sync(order, shipment_hash['shipping_method'])

      shipment = order.shipments.new(shipment_attrs)
      shipment.shipping_methods = [shipping_method].compact
      # shipment.save
      # shipment_match.update_columns(integration_syncable_id: shipment.id)
    end

    shipment
  end

  def sweetist_shipping_method_sync(order, shipping_method_hash)
    # NOT SAVING A MATCH HERE BECAUSE WE ARE FORCING INTO EITHER 'PICKUP' OR 'DELIVERY'
    delivery_is_pickup = shipping_method_hash.fetch('name','').downcase == 'pickup'
    method_name = delivery_is_pickup ? 'Pickup' : 'Local Delivery'
    shipping_method = self.vendor.shipping_methods.find_by_name(method_name)
    puts "SHIPPING METHOD FOUND? : #{shipping_method.present?.to_s.upcase}"
    return shipping_method if shipping_method.present?

    shipping_category = sweetist_shipping_category_sync
    puts "SHIPPING CATEGORY SYNC? : #{shipping_category.present?.to_s.upcase}"
    shipping_method = shipping_category.shipping_methods.new(name: method_name)
    calculator = shipping_method.build_calculator(type: "Spree::Calculator::Shipping::FlatRate", preferences: {amount: 0.to_d, currency: self.vendor.try(:currency)})
    puts "SHIPPING METHOD ERRORS: #{shipping_method.errors.full_messages}"
    shipping_method.save

    shipping_method
  end

  def sweetist_stock_location_sync #DONE
    # SWEETIST ONLY HAS ONE STOCK LOCATION THAT IS COMBINED FOR ALL BAKERIES
    # SO WE ARE ONLY GOING TO SYNC TO THE SELECTED STOCK LOCATION
    stock_location = self.vendor.stock_locations.find_by_id(self.sweetist_stock_location_id)

    stock_location
  end

  def sweetist_tax_category_sync(tax_category_hash) #DONE
    # TODO sync all taxes to Nontaxable until taxes work in Sweetist
    tax_cat_match = self.integration_sync_matches.find_or_create_by(
      sync_id: tax_category_hash['id'],
      integration_syncable_type: "Spree::TaxCategory"
    )
    tax_cat = self.vendor.tax_categories.find_by_id(tax_cat_match.integration_syncable_id)
    tax_cat ||= self.vendor.tax_categories.find_by_name(tax_category_hash['name'])
    tax_category_attrs = sweetist_map_to_sweet_obj(tax_category_hash, 'Spree::TaxCategory')

    if tax_cat
      tax_cat.update_columns(tax_category_attrs)
    else
      tax_cat = self.vendor.tax_categories.create(tax_category_attrs)
    end
    tax_cat_match.update_columns(integration_syncable_id: tax_cat.id)

    tax_cat
  end

  def sweetist_shipping_category_sync(shipping_category_hash = {}) #DONE
    # THERE IS ONLY ONE SHIPPING CATEGORY IN SWEETIST, WE ARE JUST HAVING
    # ONE DEFAULT CATEGORY IN SWEET FOR THIS. UNCOMMENT THE BELOW CODE IF
    # SYNCING NEEDS TO OCCUR

    # if shipping_category_hash.present?
    #   shipping_cat_match = self.integration_sync_matches.find_or_create_by(
    #     sync_id: shipping_category_hash['id'],
    #     integration_syncable_type: "Spree::ShippingCategory"
    #   )
    #   shipping_cat = self.vendor.shipping_categories.find_by_id(shipping_cat_match.integration_syncable_id)
    #   if shipping_cat_match.integration_syncable_id
    #     shipping_cat.update_columns(name: shipping_category_hash['name'])
    #   else
    #     shipping_cat = self.vendor.shipping_categories.find_or_create_by_name(shipping_category_hash['name'])
    #     shipping_cat_match.update_columns(integration_syncable_id: shipping_cat.id)
    #   end
    #   shipping_cat
    # else
      shipping_cat = self.vendor.shipping_categories.where(name: 'Default').first
      shipping_cat ||= self.vendor.shipping_categories.create(name: 'Default')
      puts "SHIPPING CATEGORY: #{shipping_cat.attributes}"
    # end
    shipping_cat
  end

  def sweetist_option_type_sync(option_types_hash) #DONE
    option_types = []
    option_types_hash.each do |option_type_hash|
      next if option_type_hash.fetch('name','').downcase == 'size'
      option_type = nil
      option_type_match = self.integration_sync_matches.find_or_create_by(
        sync_id: option_type_hash['id'],
        integration_syncable_type: "Spree::OptionType"
      )

      option_type_attrs = sweetist_map_to_sweet_obj(option_type_hash.except('id'), 'Spree::OptionType')

      if option_type_match.integration_syncable_id
        option_type = Spree::OptionType.find_by_id(option_type_match.integration_syncable_id)
      else
        option_type = Spree::OptionType.find_or_create_by(option_type_attrs)
        option_type_match.update_columns(integration_syncable_id: option_type.id)
      end
      option_types << option_type
    end

    option_types
  end

  def sweetist_option_value_and_pack_size_sync(option_values) #DONE
    sweet_option_values = []
    pack_size = nil
    option_values.uniq.each do |option_value_hash|
      # option type 'Size' is being converted to Pack/Size in Sweet
      if option_value_hash.fetch('option_type',{}).fetch('name','').downcase == 'size'
        pack_size = option_value_hash.fetch('presentation', '')
      else #otherwise, do the regular sync methods
        option_type = Spree::OptionType.find_by_id(
          self.integration_sync_matches.find_by(sync_id: option_value_hash['option_type_id']).integration_syncable_id
        )
        option_value_match = self.integration_sync_matches.find_or_create_by(
          sync_id: option_value_hash['id'],
          integration_syncable_type: "Spree::OptionValue"
        )
        if option_value_match.integration_syncable_id
          option_value = self.vendor.option_values.find_by_id(option_value_match.integration_syncable_id)
          option_value.update_columns(name: option_value_hash['name'], presentation: option_value_hash['presentation'])
        else
          option_value = self.vendor.option_values.find_or_create_by(name: option_value_hash['name'], presentation: option_value_hash['presentation'], option_type_id: option_type.try(:id))
        end
        option_value_match.update_columns(integration_syncable_id: option_value.try(:id))
        sweet_option_values << option_value
      end
    end

    [sweet_option_values.compact, pack_size]
  end

  def sweetist_address_sync(address_hash, addr_type = nil)
    address = nil
    country = Spree::Country.find_by_name(address_hash.fetch('country',{}).fetch('name',''))
    country ||= self.vendor.bill_address.try(:country)
    country ||= Spree::Country.find_by_name('United States')
    state = country.states.find_by_name(address_hash.fetch('state',{}).fetch('name',''))

    address_hash['addr_type'] = addr_type
    address_hash['country_id'] = country.try(:id)
    address_hash['state_id'] = state.try(:id)
    address_attrs = sweetist_map_to_sweet_obj(address_hash, 'Spree::Address')
    address_match = self.integration_sync_matches.find_or_create_by(
      sync_id: address_hash['id'],
      integration_syncable_type: "Spree::Address"
    )
    if address_match.integration_syncable_id
      address = Spree::Address.find_by_id(address_match.integration_syncable_id)
      address.update(address_attrs)
    else
      address_hash['country_id'] = country.id
      address_hash['state_id'] = state.id
      address = Spree::Address.create(address_attrs)
      address_match.update_columns(integration_syncable_id: address.id)
    end

    address
  end

  def sweetist_user_sync(user_hash)
    user = nil
    user_match = self.integration_sync_matches.find_or_create_by(
      sync_id: user_hash['id'],
      integration_syncable_type: "Spree::User"
    )
    if user_match.integration_syncable_id
      user = Spree::User.find_by_id(user_match.integration_syncable_id)
    else
      # no user_match, but let's check the email just in case
      user = Spree::User.find_by_email(user_hash['email'])
      unless user.present?
        user_hash = user_hash.except('id', 'subscribed', 'first_name', 'last_name')
        user_hash['firstname'] = user_hash['first_name']
        user_hash['lastname'] = user_hash['last_name']
        # TODO define company, bill and ship address
        # user_hash['bill_address_id'] = bill_address.id
        # user_hash['ship_address_id'] = ship_address.id
        # user = account.users.create(user_hash)
        # user.save
      end
    end
    user_match.update_columns(integration_syncable_id: user.try(:id))

    user
  end


################### MAPPING ATTRIBUTES FROM SWEETIST TO SWEET ################

  def sweetist_map_variant(hash)
    variant_hash = {}
    variant_hash['custom_attrs'] = {}
    variant_hash['custom_attrs']['sweetist'] = {}
    sweet_keys = Spree::Variant.column_names
    hash.each do |attr_name, value|

      if attr_name == 'prices'
        variant_hash['price'] = value.first.fetch('amount', 0.0)
      elsif attr_name == 'option_values'
        # sweetist_option_value_and_pack_size_sync(value) returns an array [[option_values], pack_size]
        option_values, pack_size = sweetist_option_value_and_pack_size_sync(value)
        variant_hash['option_value_ids'] = option_values.map{|ov| ov.id}
        variant_hash['pack_size'] = pack_size unless pack_size.blank?
      elsif attr_name == 'lead_time'
        variant_hash['lead_time'] = (value.to_i / 24)
        variant_hash['custom_attrs']['sweetist'][attr_name] = value.to_i
      elsif sweet_keys.include?(attr_name)
        variant_hash[attr_name] = value
      else
        variant_hash['custom_attrs']['sweetist'][attr_name] = value
      end
    end
    variant_hash.delete('stock_items_count')
    variant_hash
  end

  def sweetist_map_to_sweet_obj(hash, class_str)
    attrs_hash = {}

    exclude_attrs = %w{id updated_at created_at deleted_at}
    if class_str == 'Spree::Variant'
      attrs_hash = sweetist_map_variant(hash)
    else
      sweet_keys = class_str.constantize.column_names
      hash.each do |attr_name, value|
        next if exclude_attrs.include?(attr_name)
        if sweet_keys.include?(attr_name)
          attrs_hash[attr_name] = value
        elsif sweet_keys.include?('custom_attrs')
          attrs_hash['custom_attrs'] ||= {}
          attrs_hash['custom_attrs']['sweetist'] ||= {}
          attrs_hash['custom_attrs']['sweetist'][attr_name] = value
        end
      end
    end

    if class_str == 'Spree::Order'
      attrs_hash['number'] = Spree::Order.number_from_integration(attrs_hash['number'], self.vendor_id)
    end
    attrs_hash
  end

  def sweetist_map_state_to_sweet_order(sweet_order, sweetist_state)
    sweet_state = sweet_order.state
  end
############## END MAPPING ATTRIBUTES FROM SWEETIST TO SWEET ################


end
