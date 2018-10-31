module Spree::SweetistIntegration::Action
  extend ActiveSupport::Concern
  include Spree::Syncable
  # include Spree::SweetistIntegration::Action::Variant
  # include Spree::SweetistIntegration::Action::Order

  def sweetist_trigger(integrationable_id, integrationable_type, integration_action)
    case integrationable_type
    when 'Spree::Order'
      # no action
      self.sweetist_synchronize_order(integrationable_id, integrationable_type)
    when 'Spree::Account'
      # no action
    when 'Sweetist::Order'
      { status: 1, log: 'Order Sync from Sweetist' }
    when 'Spree::Variant'
      self.sweetist_synchronize_variant(integrationable_id, integrationable_type)
    else
      { status: -1, log: 'Unknown Integrationable Type' }
    end
  rescue Exception => e
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end



  ################## BEGIN SYNCHRONIZE ORDER #################################
  # returns hash of status and log to be displayed in integration log
  ##############################################################################
  def sweetist_synchronize_order(order_id, order_class)
    order = self.integration_item.vendor.sales_orders.find(order_id)
    # order.variants.each do |variant|
    #   sweetist_synchronize_variant(variant.id, 'Spree::Variant')
    # end
    order_hash = order.to_integration(
        self.integration_item.integrationable_options_for(order)
      ) rescue {}
    order_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: order_id, integration_syncable_type: order_class)
    if order_match.sync_id
      get_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/orders/#{order_match.sync_id}?token=#{ENV['SWEETIST_API_KEY']}")
      sweetist_order_hash = JSON.parse(get_request.body)
      if get_request.code.to_i == 200
        payload = sweetist_map_to_sweetist_order(order_hash)
        push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/orders/#{order_match.sync_id}?token=#{ENV['SWEETIST_API_KEY']}", :patch, payload)
        if push_request.code.to_s.starts_with?('20')
          # syncs line_items & shipment; returns {status: integer, log: []}
          self.sweetist_synchronize_order_associated_objects(order_hash, order_match.sync_id, sweetist_order_hash)
        else
          { status: -1, log: "#{order_hash.fetch(:name_for_integration)} => Error(#{push_request.code}) - #{push_request.message}"}
        end
      else
        { status: -1, log: "Could not find match in Sweetist to order with id => #{order.id} in Sweet" }
      end
    elsif order_hash.fetch(:channel, '').to_s.downcase == 'sweetist'
      # get_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/orders?q[number_eq]=#{order.try(:number)}&token=#{ENV['SWEETIST_API_KEY']}")
      # sweetist_order_hash = JSON.parse(get_request.body).fetch('orders',[]).first
      get_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/orders/#{order.try(:number)}?token=#{ENV['SWEETIST_API_KEY']}")
      sweetist_order_hash = get_request.code.to_i == 200 ? JSON.parse(get_request.body) : nil
      if sweetist_order_hash
        order_match.update_columns(sync_id: sweetist_order_hash.fetch('id'))
        payload = sweetist_map_to_sweetist_order(order_hash)
        push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/orders/#{sweetist_order_hash.fetch('id',nil)}?token=#{ENV['SWEETIST_API_KEY']}", :patch, payload)
        if push_request.code.to_s.starts_with?('20')
          # syncs line_items & shipment; returns {status: integer, log: []}
          self.sweetist_synchronize_order_associated_objects(order_hash, order_match.sync_id, sweetist_order_hash)

        else
          { status: -1, log: "#{order_hash.fetch(:name_for_integration)} => Error(#{push_request.code}) - #{push_request.message}"}
        end
      else
        { status: -1, log: "Could not find match in Sweetist to order with id => #{order_id} or number => #{order.display_number} in Sweet" }
      end
    else
      { status: -1, log: "Could not find match in Sweetist to order with number => #{order.display_number} in Sweet" }
    end
  rescue Exception => e
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end

  # syncs line_items & shipment; returns {status: integer, log: []}
  def sweetist_synchronize_order_associated_objects(order_hash, sweetist_order_id, sweetist_order_hash = {})
    line_item_error_logs = order_hash.fetch(:line_items,[]).map do |li_hash|
      result = sweetist_synchronize_line_item(li_hash, sweetist_order_id)
      result.fetch(:status) == 10 ? nil : result.fetch(:log)
    end.compact
    sweetist_line_item_ids = sweetist_order_hash.fetch('line_items').map{ |item| item.fetch('id').to_s }
    sweet_line_item_ids = order_hash.fetch(:line_items).map{ |item| item.fetch(:id).to_s }
    line_item_sync_ids = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::LineItem',
      integration_syncable_id: sweet_line_item_ids
    ).pluck(:sync_id)
    (sweetist_line_item_ids - line_item_sync_ids).each do |sweetist_item_id|
      destroy_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/orders/#{sweetist_order_id}/line_items/#{sweetist_item_id}?token=#{ENV['SWEETIST_API_KEY']}", :delete)
      unless destroy_request.code.to_i == 204
        line_item_error_logs << "Failed to remove line item with Sweetist id (#{sweetist_item_id})"
      end
    end
    shipment_error_logs = order_hash.fetch(:shipments,[]).map do |shipment_hash|
      result = sweetist_synchronize_shipment(shipment_hash, sweetist_order_id)
      result.fetch(:status) == 10 ? nil : result.fetch(:log)
    end.compact
    if line_item_error_logs.empty? && shipment_error_logs.empty?
      sweetist_order_transitions(order_hash, sweetist_order_id)
    else
      errors = ["Sweet had errors syncing to Sweetist"]
      errors += line_item_error_logs
      errors += shipment_error_logs
      { status: -1, log: errors.join(', ') }
    end
  end

  def sweetist_order_transitions(order_hash, sweetist_order_id)
    failure = nil
    case order_hash.fetch(:state)
    when 'approved'
      push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/orders/#{sweetist_order_id}/approved?token=#{ENV['SWEETIST_API_KEY']}", :post)
    when 'shipped' || 'review' || 'invoice'
      shipment_ids = order_hash.fetch(:shipments,[]).map {|s| s.fetch(:id) }
      self.integration_item.integration_sync_matches.where(integration_syncable_type: 'Spree::Shipment', integration_syncable_id: shipment_ids).pluck(:sync_id).compact.each do |sweetist_shipment_id|
        push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/shipments/#{sweetist_shipment_id}/ship?token=#{ENV['SWEETIST_API_KEY']}", :put)
        unless push_request.code.to_s == '200'
          failure = { status: -1, log: "#{order_hash.fetch(:name_for_integration)} => Error(#{push_request.code}) - #{push_request.message}"}
        end
      end
    else
      push_request = nil
    end
    if failure.present?
      failure
    elsif push_request.nil? || push_request.code.to_s == '200'
      { status: 10, log: "#{order_hash.fetch(:name_for_integration)} => Successfully pushed to Sweetist"}
    else
      { status: -1, log: "#{order_hash.fetch(:name_for_integration)} => Error(#{push_request.code}) - #{push_request.message}"}
    end
  end
  ################## END SYNCHRONIZE ORDER #####################################

  ################## BEGIN SYNCHRONIZE LINE ITEM ###############################
  # returns hash of status and log to be displayed in integration log
  ##############################################################################
  def sweetist_synchronize_line_item(line_item_hash, sweetist_order_id)
    line_item_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: line_item_hash.fetch(:id,nil), integration_syncable_type: 'Spree::LineItem')
    # TODO sync variant first

    if line_item_match.sync_id
      payload = sweetist_map_to_sweetist_line_item(line_item_hash)
      push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/orders/#{sweetist_order_id}/line_items/#{line_item_match.sync_id}?token=#{ENV['SWEETIST_API_KEY']}", :patch, payload)
    elsif false
      # TODO find line item by variant

    else
      payload = sweetist_map_to_sweetist_line_item(line_item_hash)
      payload[:line_item][:order_id] = sweetist_order_id
      push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/orders/#{sweetist_order_id}/line_items?token=#{ENV['SWEETIST_API_KEY']}", :post, payload)
    end

    if push_request.code.to_s.starts_with?('20')
      sweetist_line_item = JSON.parse(push_request.body)
      line_item_match.update_columns(sync_id: sweetist_line_item.fetch('id',nil))
      { status: 10, log: "#{line_item_hash.fetch(:item_name,'')} saved to order"}
    else
      { status: -1, log: "#{line_item_hash.fetch(:item_name,'')} => Error(#{push_request.code}) - #{push_request.message}"}
    end

  rescue Exception => e
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end
  ################## END SYNCHRONIZE LINE ITEM #################################

  ################## BEGIN SYNCHRONIZE LINE ITEM ###############################
  # returns hash of status and log to be displayed in integration log
  ##############################################################################
  def sweetist_synchronize_shipment(shipment_hash, sweetist_order_id)
    shipment_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: shipment_hash.fetch(:id,nil), integration_syncable_type: 'Spree::LineItem')
    payload = sweetist_map_to_sweetist_shipment(shipment_hash)

    shipment_id_or_number = !!shipment_match.sync_id ? shipment_match.sync_id : shipment_hash.fetch(:number,nil)

    get_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/orders/#{sweetist_order_id}/shipments/#{shipment_id_or_number}?token=#{ENV['SWEETIST_API_KEY']}")
    if get_request.code.to_i == 200
      push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/shipments/#{shipment_id_or_number}?token=#{ENV['SWEETIST_API_KEY']}", :patch, payload)
    else
      payload[:shipment][:order_id] = sweetist_order_id
      push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/shipments?token=#{ENV['SWEETIST_API_KEY']}", :post, payload)
    end

    if push_request.code.to_s.starts_with?('20')
      sweetist_shipment_hash = JSON.parse(push_request.body)
      shipment_match.update_columns(sync_id: sweetist_shipment_hash.fetch('id',nil))
      { status: 10, log: "Shipment #{shipment_hash.fetch(:number,'')} saved to order"}
    else
      { status: -1, log: "Shipment #{shipment_hash.fetch(:number,'')} => Error(#{push_request.code}) - #{push_request.message}"}
    end

  rescue Exception => e
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end
  ################## END SYNCHRONIZE LINE ITEM #################################

  ################## BEGIN SYNCHRONIZE VARIANT #################################
  # returns hash of status and log to be displayed in integration log
  ##############################################################################
  def sweetist_synchronize_variant(variant_id, variant_class)

    variant_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_id, integration_syncable_type: 'Spree::Variant')
    # .synced_at < Time.current - 2.minute
    variant = Spree::Variant.find(variant_id)
    variant_hash = variant.to_integration(
        self.integration_item.integrationable_options_for(variant)
      )
    master_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: variant_hash.fetch(:master,{}).try(:id), integration_syncable_type: 'Spree::Variant')
    # # Master - sync the master first before syncing variants
    # MOVING THIS LOWER SO THAT IT IS ONLY DONE IF THE VARIANT DOESN'T EXIST ALREADY
    # unless variant_hash.fetch(:is_master)
    #   sync_master = self.sweetist_synchronize_variant(variant_hash.fetch(:master).try(:id), 'Spree::Variant')
    #   if sync_master.fetch(:status)
    #     master = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: variant_hash.fetch(:master).try(:id), integration_syncable_type: 'Spree::Variant')
    #   else
    #     return sync_master
    #   end
    # end

    # Variant
    if variant_match.sync_id
      get_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/variants?q[id_eq]=#{variant_match.try(:sync_id)}&token=#{ENV['SWEETIST_API_KEY']}")
    else
      get_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/variants?q[sku_eq]=#{variant_hash.fetch(:sku,'')}&token=#{ENV['SWEETIST_API_KEY']}")
    end
    sweetist_variant_hash = JSON.parse(get_request.body).fetch('variants', []).first
    if sweetist_variant_hash.present?
      variant_match.update_columns(sync_id: sweetist_variant_hash.fetch('id',nil)) unless variant_match.sync_id
      if self.integration_item.sweetist_overwrite_conflicts_in.to_s.downcase == 'sweetist'
        if variant_hash.fetch(:is_master)
          payload = sweetist_map_to_sweetist_product(variant_hash)
          push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/products/#{sweetist_variant_hash.fetch('product_id',nil)}?token=#{ENV['SWEETIST_API_KEY']}", :patch, payload)
          unless push_request.code.to_s.starts_with?('20')
            return { status: -1, log: "#{variant_hash.fetch(:name_for_integration)} => Error(#{push_request.code}) - #{push_request.message}"}
          end
        end
        payload = sweetist_map_to_sweetist_variant(variant_hash)
        push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/variants/#{variant_match.sync_id}?token=#{ENV['SWEETIST_API_KEY']}", :patch, payload)

        if push_request.code.to_s.starts_with?('20')
          { status: 10, log: "#{variant_hash.fetch(:name_for_integration)} => Successfully pushed to Sweetist"}
        else
          { status: -1, log: "#{variant_hash.fetch(:name_for_integration)} => Error(#{push_request.code}) - #{push_request.message}"}
        end
      elsif self.integration_item.sweetist_overwrite_conflicts_in.to_s.downcase == 'sweet'
        # TODO override changes to variant in Sweet
        { status: -1, log: "#{variant_hash.fetch(:name_for_integration)} => Override in Sweet is not yet implemented."}
      else
        { status: 10, log: "#{variant_hash.fetch(:name_for_integration)} => No conflict resolution." }
      end
    elsif sweetist_variant_hash.blank?
      if variant_hash.fetch(:is_master)
        payload = sweetist_map_to_sweetist_product(variant_hash)
        push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/products?token=#{ENV['SWEETIST_API_KEY']}", :post, payload)
        sweetist_variant_hash = JSON.parse(push_request.body).fetch('master',{})
      else
        sync_master = self.sweetist_synchronize_variant(variant_hash.fetch(:master).try(:id), 'Spree::Variant')
        if sync_master.fetch(:status)
          master = self.integration_item.integration_sync_matches.find_by(integration_syncable_id: variant_hash.fetch(:master).try(:id), integration_syncable_type: 'Spree::Variant')
        else
          return sync_master
        end

        master_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/variants/#{master_match.sync_id}?token=#{ENV['SWEETIST_API_KEY']}")
        sweetist_master = JSON.parse(master_request.body)
        sweetist_product_id = sweetist_master.fetch('product_id', nil)
        payload = sweetist_map_to_sweetist_variant(variant_hash)
        payload[:variant][:product_id] = sweetist_product_id
        push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/variants?token=#{ENV['SWEETIST_API_KEY']}", :post, payload)
        sweetist_variant_hash = JSON.parse(push_request.body)
      end

      if push_request.code.to_s.starts_with?('20')
        variant_match.update_columns(sync_id: sweetist_variant_hash.fetch('id',nil)) unless variant_match.sync_id
        { status: 10, log: "#{variant_hash.fetch(:name_for_integration)} => Successfully pushed to Sweetist"}
      else
        { status: -1, log: "#{variant_hash.fetch(:name_for_integration)} => Error(#{push_request.code}) - #{push_request.message}"}
      end

    else
      { status: -1, log: "#{variant_hash.fetch(:name_for_integration)} => Error(#{get_request.code}) - #{get_request.message}"}
    end
  rescue Exception => e
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end
  ################## END SYNCHRONIZE VARIANT ###################################

  ################## BEGIN SYNCHRONIZE OPTION VALUES ###########################
  # returns an array of Sweetist option value hashes
  ##############################################################################
  def sweetist_sync_option_values(option_values_arr)
    sweetist_option_values = option_values_arr.map do |ov_hash|
      option_value_match = nil
      # check if syncing pack_size as an option_value
      unless ov_hash.fetch(:option_type,{}).fetch(:name,'').to_s.downcase == 'size'
        option_value_match = self.integration_item.integration_sync_matches.find_or_create_by(
          integration_syncable_id: ov_hash['id'],
          integration_syncable_type: "Spree::OptionValue"
        )
      end
      payload = sweetist_map_to_sweetist_option_value(ov_hash)
      sweetist_option_type_id = payload.fetch(:option_value, {}).fetch(:option_type_id)

      # if we have a match saved && found in Sweetist
      if option_value_match.try(:sync_id) && send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/option_values/#{option_value_match.sync_id}?token=#{ENV['SWEETIST_API_KEY']}").code.to_i == 200
        push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/option_values/#{option_value_match.sync_id}?token=#{ENV['SWEETIST_API_KEY']}", :patch, payload)
      # no match saved or not found or syncing pack_size as an option_value
      else
        get_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/option_values?q[option_type_id_eq]=#{sweetist_option_type_id}&q[name_eq]=#{ov_hash.fetch(:name,'')}&token=#{ENV['SWEETIST_API_KEY']}")
        sweetist_option_value = JSON.parse(get_request.body).first
        if sweetist_option_value
          sweetist_ov_id = sweetist_option_value.fetch('id')
          push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/option_values/#{sweetist_ov_id}?token=#{ENV['SWEETIST_API_KEY']}", :patch, payload)
        else
          push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/option_values/?token=#{ENV['SWEETIST_API_KEY']}", :post, payload)
        end
      end
      new_sweetist_option_value = JSON.parse(push_request.body)
      option_value_match.update_columns(sync_id: new_sweetist_option_value.fetch('id',nil)) if option_value_match.present?

      new_sweetist_option_value
    end
  end
  ################## END SYNCHRONIZE OPTION VALUES #############################

  ################## BEGIN SYNCHRONIZE OPTION TYPES ############################
  # returns Sweetist option_type hash
  ##############################################################################
  def sweetist_sync_option_type(option_type_hash)
    option_type_match = nil
    # check if syncing pack_size as an option_type
    unless option_type_hash.fetch(:name,'').to_s.downcase == 'size'
      option_type_match = self.integration_item.integration_sync_matches.find_or_create_by(
        integration_syncable_id: option_type_hash['id'],
        integration_syncable_type: "Spree::OptionValue"
      )
    end
    payload = sweetist_map_to_sweetist_option_type(option_type_hash)
    # if we have a match saved && found in Sweetist
    if option_type_match.try(:sync_id) && send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/option_types/#{option_type_match.sync_id}?token=#{ENV['SWEETIST_API_KEY']}").code.to_i == 200
      push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/option_types/#{option_type_match.sync_id}?token=#{ENV['SWEETIST_API_KEY']}", :patch, payload)
    # no match saved or not found or syncing pack_size as an option_type
    else
      get_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/option_types?q[name_eq]=#{option_type_hash.fetch(:name,'')}&token=#{ENV['SWEETIST_API_KEY']}")
      sweetist_option_type = JSON.parse(get_request.body).first
      if sweetist_option_type
        sweetist_ot_id = sweetist_option_type.fetch('id', nil)
        push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/option_types/#{sweetist_ot_id}?token=#{ENV['SWEETIST_API_KEY']}", :patch, payload)
      else
        push_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/option_types/?token=#{ENV['SWEETIST_API_KEY']}", :post, payload)
      end
    end
    new_sweetist_option_type = JSON.parse(push_request.body)
    option_type_match.update_columns(sync_id: new_sweetist_option_type.fetch('id',nil)) if option_type_match.present?

    new_sweetist_option_type
  end
  ################## END SYNCHRONIZE OPTION TYPES ##############################

  ################## BEGIN SYNCHRONIZE TAX CATEGORY ############################
  # returns Sweetist tax_category hash.  It does not sync tax categories
  # directly between Sweet and Sweetist, but instead maps to Sweetist based on
  # whether the category is taxable or not
  ##############################################################################
  def sweetist_sync_tax_category(tax_category_id)
    tax_category = self.integration_item.vendor.tax_categories.find_by_id(tax_category_id)
    return nil unless tax_category
    if tax_category.tax_rates.any? {|tax_rate| tax_rate.amount > 0}
      get_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/tax_categories?q[tax_rates_amount_not_eq]=0&token=#{ENV['SWEETIST_API_KEY']}")
    else
      get_request = send_request("#{ENV['SWEETIST_INTEGRATION_URL']}/api/tax_categories?q[tax_rates_amount_eq]=0&token=#{ENV['SWEETIST_API_KEY']}")
    end

    JSON.parse(get_request.body).fetch('tax_categories',[]).first || {}
  end
  ################## END SYNCHRONIZE TAX CATEGORY ##############################
  # returns Sweetist tax_category hash.  It does not sync tax categories
  # directly between Sweet and Sweetist, but instead maps to Sweetist based on
  # whether the category is taxable or not
  ##############################################################################

  def sweetist_safe_string(string)
    string.nil? ? "" : string.gsub(/'/, {"'" => "\\'"})
  end

  private
  ############# BEGIN MAPPING ATTRIBUTES FROM SWEET TO SWEETIST ###############
  def sweetist_map_to_sweetist_order(order_hash)
    return {} if order_hash.empty?
    order_match = self.integration_item.integration_sync_matches.where(integration_syncable_id: order_hash.fetch(:id), integration_syncable_type: 'Spree::Order').first

    state = order_hash.fetch(:state,'')
    {
      order:{
        # number: order_hash.fetch(:number, ''),
        item_total: order_hash.fetch(:item_total, 0),
        state: (Spree::Order::States[state] > Spree::Order::States['approved']) ? 'approved' : state,
        adjustment_total: order_hash.fetch(:adjustment_total, 0),
        # user_id: order.user_id, # don't want to send this because users are not synced
        completed_at: order_hash.fetch(:completed_at, nil),
        # bill_address_id: order.bill_address_id, may need a find or create in Sweetist
        # ship_address_id: order.ship_address_id,
        # is_gift: sweetist_vars.fetch('is_gift', false),
        # gift_note: sweetist_vars.fetch('gift_note', ''),
        # service_fee: sweetist_vars.fetch('service_fee', 0),
        # fulfillment_time: sweetist_vars.fetch('fulfillment_time', ''),
        # fulfillment_time_window: sweetist_vars.fetch('fulfillment_time_window', '')
        # bill_address: sweetist_map_to_sweetist_address(order.bill_address),
        # ship_address: sweetist_map_to_sweetist_address(order.ship_address),

      }.compact.merge(order_hash.fetch(:customer_attrs, {}).fetch('sweetist', {}))
    }
  end

  def sweetist_map_to_sweetist_address(address = nil)
    return {} if address.nil?
    address_match = self.integration_item.integration_sync_matches.where(integration_syncable_id: address.id, integration_syncable_type: 'Spree::Address').first
    address_hash = address.to_integration(
        self.integration_item.integrationable_options_for(address)
      )
    {
      address:{
        firstname: address_hash.fetch(:firstname,nil),
        lastname: address_hash.fetch(:lastname,nil),
        address1: address_hash.fetch(:address1,nil),
        address2: address_hash.fetch(:address2,nil),
        city: address_hash.fetch(:city,nil),
        zipcode: address_hash.fetch(:zipcode,nil),
        phone: address_hash.fetch(:phone,nil),
        state_name: address_hash.fetch(:state_name,nil)
      }
    }.compact
  end

  def sweetist_map_to_sweetist_shipment(shipment_hash)
    return {} if shipment_hash.empty?
    shipment_match = self.integration_item.integration_sync_matches.where(integration_syncable_id: shipment_hash.fetch(:id), integration_syncable_type: 'Spree::Shipment').first
    {
      shipment: {
        tracking: shipment_hash.fetch(:tracking,nil),
        number: shipment_hash.fetch(:number,nil),
        cost: shipment_hash.fetch(:cost,nil),
        shipped_at: shipment_hash.fetch(:shipped_at,nil),
        state: shipment_hash.fetch(:state, nil)
      }.compact
    }
  end

  def sweetist_map_to_sweetist_line_item(line_item_hash)
    return {} if line_item_hash.blank?
    line_item_match = self.integration_item.integration_sync_matches.where(integration_syncable_id: line_item_hash.fetch(:id, nil), integration_syncable_type: 'Spree::LineItem').first
    variant = Spree::Variant.find(line_item_hash.fetch(:variant_id, nil))
    variant_hash = variant.to_integration(
        self.integration_item.integrationable_options_for(variant)
      )
    sweetist_synchronize_variant(variant_hash.fetch(:id), 'Spree::Variant')
    variant_match = self.integration_item.integration_sync_matches.where(integration_syncable_id: variant_hash.fetch(:id, nil), integration_syncable_type: 'Spree::Variant').first
    {
      line_item: {
        variant_id: variant_match.try(:sync_id),
        quantity: line_item_hash.fetch(:quantity, nil),
        price: line_item_hash.fetch(:price, nil),
        currency: line_item_hash.fetch(:currency, nil)
      }.compact
    }
  end

  def sweetist_map_to_sweetist_variant(variant_hash)
    return {} if variant_hash.fetch(:id, nil).nil?
    variant_match = self.integration_item.integration_sync_matches.where(integration_syncable_id: variant_hash.fetch(:id), integration_syncable_type: 'Spree::Variant').first
    size_value = {
      name: variant_hash.fetch(:pack_size),
      presentation: variant_hash.fetch(:pack_size),
      option_type: {
        name: 'Size',
        presentation: 'Size'
      }
    }
    option_values_arr = variant_hash.fetch(:option_values)
    option_values_arr << size_value unless variant_hash.fetch(:pack_size,nil).blank?
    {
      variant: {
        # is_master: variant_hash.fetch(:is_master, nil),
        sku: variant_hash.fetch(:sku, nil),
        price: variant_hash.fetch(:price, nil),
        cost_price: variant_hash.fetch(:cost_price, nil),
        track_inventory: variant_hash.fetch(:track_inventory, false),
        weight: variant_hash.fetch(:weight,nil),
        height: variant_hash.fetch(:height,nil),
        width: variant_hash.fetch(:width,nil),
        depth: variant_hash.fetch(:depth,nil),
        option_value_ids: sweetist_sync_option_values(option_values_arr).map{|ov_hash| ov_hash.fetch('id',nil)}.compact
        # not sending lead time because of difference from hours and days
      }.compact.merge(variant_hash.fetch(:custom_attrs, {}).fetch('sweetist', {}))
    }
  end

  def sweetist_map_to_sweetist_option_value(ov_hash)
    {
      option_value: {
        name: ov_hash.fetch(:name,nil),
        presentation: ov_hash.fetch(:presentation,nil),
        option_type_id: sweetist_sync_option_type(ov_hash.fetch(:option_type,{})).fetch('id',nil)
      }.compact
    }
  end

  def sweetist_map_to_sweetist_option_type(ot_hash)
    {
      option_type: {
        name: ot_hash.fetch(:name,nil),
        presentation: ot_hash.fetch(:presentation,nil),
      }.compact
    }
  end

  def sweetist_map_to_sweetist_product(master_variant_hash)
    option_types_arr = master_variant_hash.fetch(:product,{}).fetch(:option_types,[]) + [{name: 'Size',presentation: 'Size'}] rescue [{name: 'Size',presentation: 'Size'}]

    {
      product: {
        name: master_variant_hash.fetch(:product,{}).fetch(:name, nil),
        bakery_id: self.integration_item.sweetist_bakery_id,
        description: master_variant_hash.fetch(:product,{}).fetch(:description,nil),
        available_on: master_variant_hash.fetch(:product,{}).fetch(:available_on,nil),
        meta_description: master_variant_hash.fetch(:product,{}).fetch(:meta_description,nil),
        meta_keywords: master_variant_hash.fetch(:product,{}).fetch(:meta_keywords, nil),
        price: master_variant_hash.fetch(:price,nil),
        sku: master_variant_hash.fetch(:sku,nil),
        weight: master_variant_hash.fetch(:weight,nil),
        height: master_variant_hash.fetch(:height,nil),
        width: master_variant_hash.fetch(:width,nil),
        depth: master_variant_hash.fetch(:depth,nil),
        shipping_category: "Default", #Sweetist will do a find or create by name for shipping category
        tax_category_id: sweetist_sync_tax_category(master_variant_hash.fetch(:product,{}).fetch(:tax_category_id,nil)).fetch('id',nil),
        cost_currency: master_variant_hash.fetch(:cost_currency,nil),
        cost_price: master_variant_hash.fetch(:cost_price,nil),
        option_type_ids: option_types_arr.map{|ot_hash| sweetist_sync_option_type(ot_hash).fetch('id',nil)}.compact
      }.compact
    }
  end

  ############### END MAPPING ATTRIBUTES FROM SWEET TO SWEETIST ################

end
