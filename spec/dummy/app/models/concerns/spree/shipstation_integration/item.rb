module Spree::ShipstationIntegration::Item

  def shipstation_public_methods
    {
      endpoint: { title: 'Endpoint', class: '' }
    }
  end

  def shipstation_methods
    {
      authenticate: { title: 'Authenticate', class: ''},
      reset_password: { title: 'Reset Password', class: 'btn btn-danger'}
    }
  end

  def shipstation_callbacks
    {
      before_create: ['shipstation_generate_defaults'],
      after_create: ['shipstation_update_url']
    }
  end

  def shipstation_generate_defaults
    self.shipstation_username = self.vendor.name.titleize.tr(' ', '').underscore
    self.shipstation_url = shipstation_url
    self.shipstation_password = SecureRandom.hex(6)
    self.shipstation_overwrite_shipping_cost = false
    self.shipstation_weight_units = 'oz'
    self.shipstation_unpaid_status = 'cart'
    self.shipstation_paid_status = 'complete, approved'
    self.shipstation_shipped_status = 'shipped, review, invoice'
    self.shipstation_canceled_status = 'canceled, void'
    self.shipstation_on_hold_status = 'on-hold'
    self.shipstation_blacklist_order_numbers = []
    self.order_sync = false
    self.account_sync = false
    self.variant_sync = false
    self.shipstation_include_lots = self.vendor.try(:lot_tracking)
    self.shipstation_include_assembly_lots = false
    self.shipstation_round = 'round'
  end
  def shipstation_should_sync_order(order)
    self.order_sync?
  end

  def shipstation_update_url
    self.settings ||= {}
    self.settings['shipstation'] ||= {}
    self.settings['shipstation']['url'] = shipstation_url
    self.save
  end

  # form fields

  def shipstation_custom_field_options
    [
      ["#{self.vendor.try(:order_date_text).to_s.capitalize} Date",'delivery_date'],
      ['Invoice Date', 'invoice_date'],
      ['Due Date', 'due_date'],
      ['PO Number', 'po_number'],
      ['Channel', 'channel'],
      ['Invoice Number', 'invoice_number']
    ]
  end
  def shipstation_custom_field_options_display(value)
    shipstation_custom_field_options.to_h.key(value)
  end

  def shipstation_url
    if Rails.env == 'staging'
      "https://staging.onsweet.co/api/integrations/#{self.id}/execute?name=endpoint"
    else
      "https://app.onsweet.co/api/integrations/#{self.id}/execute?name=endpoint"
    end
  end

  def shipstation_limit_shipping_methods?
    true
  end

  def shipstation_url=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['url'] = value
  end

  def shipstation_username
    self.settings['shipstation']['username'] rescue ''
  end
  def shipstation_username=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['username'] = value
  end
  def shipstation_password
    self.settings['shipstation']['password'] rescue ''
  end
  def shipstation_password=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['password'] = value
  end
  def shipstation_email_type
    self.settings['shipstation']['email_type'] || '' rescue ''
  end
  def shipstation_email_type=(value)
    self.settings ||= {}
    self.settings['shipstation'] ||= {}
    self.settings['shipstation']['email_type'] = value
  end
  def shipstation_email_type_options
    {'Account' => '', 'Shipment' => 'shipment'}
  end
  def shipstation_overwrite_shipping_cost
    ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['shipstation']['overwrite_shipping_cost']) rescue false
  end
  def shipstation_overwrite_shipping_cost=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['overwrite_shipping_cost'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def shipstation_weight_units
    self.settings['shipstation']['weight_units'] rescue ''
  end
  def shipstation_weight_units=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['weight_units'] = value
  end
  def shipstation_include_lots
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['shipstation']['include_lots']) rescue !!self.vendor.try(:lot_tracking)
  end
  def shipstation_include_lots=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['include_lots'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def shipstation_include_assembly_lots
    !!ActiveRecord::Type::Boolean.new.type_cast_from_database(self.settings['shipstation']['include_assembly_lots']) rescue false
  end
  def shipstation_include_assembly_lots=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['include_assembly_lots'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end
  def shipstation_custom_field_1
    self.settings['shipstation']['custom_field_1'] rescue ''
  end
  def shipstation_custom_field_1=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['custom_field_1'] = value
  end
  def shipstation_custom_field_2
    self.settings['shipstation']['custom_field_2'] rescue ''
  end
  def shipstation_custom_field_2=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['custom_field_2'] = value
  end
  def shipstation_custom_field_3
    self.settings['shipstation']['custom_field_3'] rescue ''
  end
  def shipstation_custom_field_3=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['custom_field_3'] = value
  end
  def shipstation_round
    self.settings.fetch('shipstation', {}).fetch('round', 'round') rescue 'round'
  end
  def shipstation_round=(value)
    return unless %w[round floor ceil].include?(value)
    self.settings ||= {}
    self.settings['shipstation'] ||= {}
    self.settings['shipstation']['round'] = value
  end
  def shipstation_name
    self.settings.fetch('shipstation', {}).fetch('username', '')
  end
  def shipstation_unpaid_status
    self.settings['shipstation']['unpaid_status'] rescue ''
  end
  def shipstation_unpaid_status=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['unpaid_status'] = value
  end
  def shipstation_paid_status
    self.settings['shipstation']['paid_status'] rescue ''
  end
  def shipstation_paid_status=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['paid_status'] = value
  end
  def shipstation_shipped_status
    self.settings['shipstation']['shipped_status'] rescue ''
  end
  def shipstation_shipped_status=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['shipped_status'] = value
  end
  def shipstation_canceled_status
    # self.settings['shipstation']['canceled_status'] rescue ''
    'canceled, void'
  end
  def shipstation_canceled_status=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['canceled_status'] = value
  end
  def shipstation_on_hold_status
    self.settings['shipstation']['on_hold_status'] rescue ''
  end
  def shipstation_on_hold_status=(value)
    self.settings = {} unless self.settings
    self.settings['shipstation'] = {} unless self.settings['shipstation']
    self.settings['shipstation']['on_hold_status'] = value
  end

  # Add display numbers to blacklist_order_numbers array to prevent sending
  # to shipstation
  def shipstation_blacklist_order_numbers
    self.settings['shipstation']['blacklist_order_numbers'] || [] rescue []
  end
  def shipstation_blacklist_order_numbers=(value)
    unless value.is_a?(Array)
      raise Exception.new('Invalid type. Must supply array.')
    end
    self.settings ||= {}
    self.settings['shipstation'] ||= {}
    self.settings['shipstation']['blacklist_order_numbers'] = value
  end
  def shipstation_formatted_blacklist_order_numbers
    shipstation_blacklist_order_numbers.map{|n| Spree::Order.number_from_integration(n, vendor_id)}
  end

  # action methods

  def shipstation_endpoint(request, params)
    if shipstation_authenticate(params['SS-UserName'], params['SS-Password'])
      if request.query_string.include?('shipnotify')
        # shipstation post/update to sweet
        response, status = shipstation_shipnotify(request, params)
      elsif request.query_string.include?('export')
        # shipstation pull orders
        action = self.integration_actions.create(integrationable_type: 'Spree::Order')
        action.trigger!
        response, status, error = shipstation_build(params)
        action.update_columns(execution_log: "#{action.execution_log}, #{error}", status: -2) if error
      else
        response = {}.to_xml
        status = 405#Method Not Allowed
      end
    else
      action = self.integration_actions.create(integrationable_type: 'Spree::Order', execution_log: "Invalid Username or Password supplied by Shipstation", status: -2)
      response = {}.to_xml
      status = 401 #Unauthorized
    end
    { xml: response, status: status }
  end

  def shipstation_reset_password(params, integration_url)
    self.shipstation_password = SecureRandom.hex(6)
    self.save
    { url: "#{integration_url}/edit", flash: { success: "ShipStation password has been updated." } }
  end

  def shipstation_authenticate(username, password)
    username == self.shipstation_username && password == self.shipstation_password
  end

  def shipstation_shipnotify(request, params)
    @number = Spree::Order.number_from_integration(params[:order_number], self.vendor_id)

    @tracking = params[:tracking_number]
    status = 422
    errors = []
    order = self.vendor.sales_orders.find_by_number(@number)
    ss_order_hash = Hash.from_xml(request.body)

    action = self.integration_actions.create(integrationable_type: 'Spree::Order', integrationable_id: order.try(:id))
    action.trigger!
    if order
      begin
        order.shipments.first.update_columns(tracking: @tracking)
        if self.shipstation_overwrite_shipping_cost
          shipstation_override_shipping_cost(order, ss_order_hash)
        else
          errors += shipstation_save_shipping_adjustment(order, ss_order_hash)
        end

        statuts, errors = shipstation_ship_order(order)
      rescue => e
        if e.try(:message)
          errors << e.try(:message)
        else
          errors << 'There was an error processing your request'
        end
        status = 422
      end
    else
      errors << 'Unable to find order'
      status = 404
    end

    if errors.empty?
      action.update_columns(status: 5)
      response = {text: 'success'}.to_xml
      status = 200
    else
      action.update_columns(status: -2, execution_log: errors.join(', '))
      response = {text: errors.join(', ')}.to_xml #400 bad request
    end
    [response, status]
  end

  def shipstation_override_shipping_cost(order, ss_order_hash)
    order.update_columns(
      override_shipment_cost: true,
      shipment_total: ss_order_hash.fetch('ShipNotice', {}).fetch('ShippingCost', 0).to_d
    )
    order.shipments.each do |s|
      s.refresh_rates
      s.update_amounts
    end
    unless order.contents.update_cart({order_state: order.state})
      order.item_count = order.quantity
      order.persist_totals
      Spree::OrderUpdater.new(order).update
    end
  end

  def shipstation_save_shipping_adjustment(order, ss_order_hash)
    shipment = order.shipments.first
    errors = []
    adjustment_amount = -1.0 * (order.shipment_total - ss_order_hash.fetch('ShipNotice', {}).fetch('ShippingCost', 0).to_d)
    if shipment
      adjustment = shipment.adjustments.find_by(label: 'ss_rate')
      adjustment ||= shipment.adjustments.create(label: 'ss_rate', amount: adjustment_amount, order_id: order.id)
    else
      errors << 'No shipment exists'
    end
    errors
  end

  def shipstation_ship_order(order)
    errors = []
    if order.inventory_units.where(state: 'backordered').present?
      status = 409 #Conflict
      errors << "Some items in your Order ##{order.display_number} are backordered."
      order.trigger_transition
    elsif order.is_valid?
      order.line_items.each {|li| li.shipped_qty = li.quantity}
      order.next
      order.shipments.each {|s| s.ship! }
      status = 200
    else
      order.trigger_transition rescue nil
      errors += order.errors_including_line_items
      status = 422
    end
    [status, errors]
  end
  # Builds the response xml for Sweet to Export orders (ShipStation Import orders)
  # ShipStation expects to receive all orders between start and end date regardless
  # of the order state.

  def shipstation_shipments_to_sync(params)
    query_string = '
      spree_orders.completed_at IS NOT NULL
      AND spree_orders.vendor_id = ?
      AND spree_orders.updated_at BETWEEN ? AND ?
      AND spree_orders.channel IN (?)
      AND spree_orders.number NOT IN (?)'

    if self.whitelist_shipping_methods?
      query_string += ' AND spree_orders.shipping_method_id IN (?)'
    elsif self.blacklist_shipping_methods?
      query_string += ' AND spree_orders.shipping_method_id NOT IN (?)'
    end

    #subtract 1 day and 1 hour to adjust for incorrect start date being sent from ShipStation
    start_date = DateHelper.ss_time_to_db(params[:start_date]) - 1.day - 1.hour
    end_date = DateHelper.ss_time_to_db(params[:end_date])

    query_values = [
      self.vendor_id,
      start_date,
      end_date,
      self.sales_channels_arr,
      self.shipstation_formatted_blacklist_order_numbers
    ]

    unless self.sync_all_shipping_methods?
      query_values << self.shipping_method_ids
    end

    Spree::Shipment.joins(:order)
      .where(query_string, *query_values)
      .page(params[:page])
  end
  def shipstation_build(params)
    date_format = "%m/%d/%Y %H:%M"
    date_only_format = "%m/%d/%Y"
    status = 200
    error = nil
    begin
      numbers = self.shipstation_blacklist_order_numbers
      self.shipstation_blacklist_order_numbers = [''] if numbers.blank?
      @shipments = shipstation_shipments_to_sync(params)

      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        # ShipStation will send a request for each page based on total # of pages
        # All possible xml fields are listed below, uncomment to include
        xml.Orders(pages: @shipments.total_pages) {
          @shipments.each do |shipment|
            order = shipment.order

            xml.Order {
              xml.OrderID        shipment.id
              xml.OrderNumber    order.display_number
              xml.OrderDate      order.completed_at.strftime(date_format)
              xml.OrderStatus    order.state
              xml.LastModified   order.updated_at.strftime(date_format)
              xml.ShippingMethod order.shipping_method.try(:name) || 'Shipping'
              # xml.PaymentMethod
              xml.OrderTotal     order.total
              xml.TaxAmount      order.tax_total
              xml.ShippingAmount order.ship_total
              xml.CustomerNotes  order.special_instructions
              # xml.InternalNotes
              # xml.Gift
              # xml.GiftMessage
              if self.shipstation_custom_field_1.present?
                  attribute = order.send("#{self.shipstation_custom_field_1}")
                  attribute = attribute.strftime(date_only_format) if attribute.is_a? Time
                xml.CustomField1   attribute
              end
              if self.shipstation_custom_field_2.present?
                attribute = order.send("#{self.shipstation_custom_field_2}")
                attribute = attribute.strftime(date_only_format) if attribute.is_a? Time
                xml.CustomField2   attribute
              end
              if self.shipstation_custom_field_3.present?
                attribute = order.send("#{self.shipstation_custom_field_3}")
                attribute = attribute.strftime(date_only_format) if attribute.is_a? Time
                xml.CustomField3   attribute
              end
              # xml.CustomField2   order.special_instructions
              # xml.CustomField3   order.special_instructions
              # accepts upto 3 custom fields

              # xml.Source

              xml.Customer {
                xml.CustomerCode order.valid_emails.first.to_s.slice(0, 50)
                bill_address = order.bill_address || order.account.bill_address
                ship_address = order.ship_address || order.account.default_shipping_address

                bill_name = bill_address.try(:full_name)
                bill_name = bill_address.try(:company) if bill_name.blank?
                bill_name = order.account.fully_qualified_name if bill_name.blank?

                ship_name = ship_address.try(:full_name)
                ship_name = ship_address.try(:company) if ship_name.blank?
                ship_name = order.account.fully_qualified_name if ship_name.blank?

                bill_company_name = bill_address.try(:company)
                bill_company_name = order.account.fully_qualified_name if bill_company_name.blank?
                xml.BillTo {
                  xml.Name       bill_name
                  xml.Company    bill_company_name unless bill_company_name == bill_name
                  xml.Phone      bill_address.try(:phone)
                  xml.Email      order.account.valid_emails_string(self.shipstation_email_type)
                }

                ship_company_name = ship_address.try(:company)
                ship_company_name = order.account.fully_qualified_name if ship_company_name.blank?
                country = nil
                country = ship_address.try(:country).try(:iso) unless ship_address.try(:country).try(:iso).to_s.length != 2
                country ||= order.account.default_country_iso
                xml.ShipTo {
                  xml.Name       ship_name
                  xml.Company    ship_company_name unless ship_company_name == ship_name
                  xml.Address1   ship_address.try(:address1).to_s
                  xml.Address2   ship_address.try(:address2).to_s
                  xml.City       ship_address.try(:city).to_s
                  xml.State      (ship_address.try(:state).try(:abbr) || ship_address.try(:state_name)).to_s
                  xml.PostalCode ship_address.try(:zipcode).to_s
                  xml.Country    country
                  xml.Phone      ship_address.try(:phone).to_s
                }
              }
              xml.Items {
                order.line_items.joins(:variant).reorder(Spree::LineItem.company_sort(order.vendor)).each do |line|
                  variant = line.variant
                  # Accepted weight units
                  # "|pound|pounds|lb|lbs|gram|grams|gm|oz|ounces|Pound|Pounds|Lb|Lbs|Gram|Grams|Gm|Oz|Ounces|POUND|POUNDS|LB|LBS|GRAM|GRAMS|GM|OZ|OUNCES"

                  weight = variant.weight.to_f
                  if variant.weight_units == 'kg'
                    weight /= 1000.0
                  end
                  weight_units = variant.weight_units == 'kg' ? 'gm' : variant.weight_units
                  weight_units = weight_units.blank? ? self.shipstation_weight_units : weight_units
                  xml.Item {
                    # xml.LineItemID
                    xml.SKU         variant.sku
                    xml.Name        line.item_name
                    xml.ImageUrl    variant.product.images.first.try(:attachment).try(:url) unless variant.product.images.first.try(:attachment).try(:url).nil?
                    xml.Weight      weight
                    xml.WeightUnits weight_units
                    xml.Quantity    line.quantity.send(self.shipstation_round)
                    xml.UnitPrice   line.discount_price

                    if variant.option_values.present? || line.pack_size.present?
                      xml.Options {
                        if line.pack_size.present?
                          xml.Option {
                            xml.Name  'Pack_Size'
                            xml.Value line.pack_size
                          }
                        end
                        if variant.option_values.present?
                          variant.option_values.each do |value|
                            xml.Option {
                              xml.Name  value.option_type.presentation
                              xml.Value value.name
                            }
                          end
                        end
                        if self.shipstation_include_lots
                          if line.lot_number.present?
                            xml.Option {
                              xml.Name 'Lot'
                              xml.Value line.lot_number
                            }
                          end
                          if variant.is_bundle?
                            line.line_item_lots.each do |lil|
                              xml.Option {
                                xml.Name "Part Lot: #{lil.part_or_variant}"
                                xml.Value lil.display_lot({sparse: true})
                              }
                            end
                          elsif variant.is_assembly? && self.shipstation_include_assembly_lots
                            line.display_assembly_part_lot_numbers({lot_prefix: 'PARTLOT'}).split("\n").each do |lot_text|
                              xml.Option {
                                lot = lot_text.split(' - PARTLOT')
                                xml.Name "Part Lot: #{lot.first}"
                                xml.Value lot.last
                              }
                            end rescue nil
                          end
                        end
                      }
                    end
                  }
                end
              }
            }
          end
        }
      end
    rescue Exception => e
      error = e.try(:message)
      builder ||= {}
      status = 422
    end
    [builder.to_xml, status, error]
  end
end
