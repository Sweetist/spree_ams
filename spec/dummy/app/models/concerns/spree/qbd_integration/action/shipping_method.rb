module Spree::QbdIntegration::Action::ShippingMethod
  #
  # ShippingMethod
  #
  def qbd_shipping_method_step(shipping_method_id, parent_step_id = nil)
    shipping_method = Spree::ShippingMethod.find(shipping_method_id)
    shipping_method_hash = shipping_method.to_integration(
        self.integration_item.integrationable_options_for(shipping_method)
      )

    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: shipping_method_id, integration_syncable_type: 'Spree::ShippingMethod')
    if match.sync_id.nil?
      qbd_shipping_method_query_step_hash(shipping_method_id)
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      qbd_shipping_method_create_step_hash(shipping_method_id)
    else
      if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = qbd_shipping_method_query_step_hash(shipping_method_id).merge(next_step: :skip)
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        next_step = qbd_shipping_method_pull_step_hash(shipping_method_id)
      else
        next_step = qbd_shipping_method_query_step_hash(shipping_method_id).merge(next_step: :skip)
      end
    end
  end

  def qbd_shipping_method_to_ship_method_xml(xml, shipping_method_hash, match = nil)
    if match
      xml.ListID       match.try(:sync_id)
    end
    xml.Name           shipping_method_hash.fetch(:name).to_s #CHAR LIMIT 15
    xml.IsActive       true

  end

  def qbd_all_associated_matched_ship_method?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/ShipMethodQueryRs/ShipMethodRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ShipMethodRet", {})

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_ship_method_xml_to_shipping_method(response, shipping_method_hash)
    shipping_method = self.company.shipping_methods.find_by_id(shipping_method_hash.fetch(:id, nil))
    xpath_base = '//QBXML/QBXMLMsgsRs/ShipMethodQueryRs/ShipMethodRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ShipMethodRet", {})
    qbd_ship_method_hash_to_shipping_method(qbd_hash, shipping_method)
    # {
    #   # name: response.xpath("#{xpath_base}/Name").try(:children).try(:text)
    # }.delete_if { |k, v| v.blank? }

    return {}
    {}
  end

  def qbd_ship_method_hash_to_shipping_method(qbd_hash, shipping_method = nil)
    full_name = qbd_hash.fetch('Name', nil)
    shipping_method ||= self.company.shipping_methods.where(
      name: full_name
    ).first

    if shipping_method.present?
      shipping_method.name = full_name
      shipping_method.save

      return shipping_method
    end
    transaction do
      shipping_method = Spree::ShippingMethod.new(
        name: full_name
      )
      shipping_method.shipping_category_ids = self.company.shipping_category_ids
      shipping_method.zone_ids = self.company.zone_ids
      shipping_method.calculator = Spree::Calculator.create(
        type: "Spree::Calculator::Shipping::FlatRate",
        calculable_type: "Spree::ShippingMethod",
        preferences: {amount: 0.0, currency: self.company.currency }
      )

      shipping_method.save!
    end

    shipping_method
  end

  def qbd_find_shipping_method_by_id_or_name(hash, base_key)
    qbd_shipping_method_id = hash.fetch(base_key, {}).fetch('ListID', nil)
    qbd_shipping_method_full_name = hash.fetch(base_key, {}).fetch('FullName', nil)
    return nil unless qbd_shipping_method_id.present? || qbd_shipping_method_full_name.present?

    match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::ShippingMethod',
      sync_id: qbd_shipping_method_id
    ).first

    shipping_method = self.company.shipping_methods.where(id: match.try(:integration_syncable_id)).first
    shipping_method ||= self.company.shipping_methods.where(name: qbd_shipping_method_full_name).first

    if shipping_method.nil?
      sync_step = self.integration_steps.find_or_initialize_by(
        integrationable_type: 'Spree::ShippingMethod',
        sync_type: 'ShippingMethod',
        sync_id: qbd_shipping_method_id
      )
      sync_step.parent_id ||= self.current_step.try(:id)
      sync_step.details = qbd_shipping_method_pull_step_hash.merge(
        {'qbxml_query_by' => 'ListID', 'sync_id' => qbd_shipping_method_id, 'sync_full_name' => qbd_shipping_method_full_name}
      )

      sync_step.save
    end

    shipping_method
  end

  def qbd_shipping_method_query_step_hash(shipping_method_id = nil)
    { step_type: :query, object_id: shipping_method_id, object_class: 'Spree::ShippingMethod', qbxml_class: 'ShipMethod', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  def qbd_shipping_method_pull_step_hash(shipping_method_id = nil)
    { step_type: :pull, next_step: :skip, object_id: shipping_method_id, object_class: 'Spree::ShippingMethod', qbxml_class: 'ShipMethod', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  def qbd_shipping_method_create_step_hash(shipping_method_id = nil)
    { step_type: :create, object_id: shipping_method_id, object_class: 'Spree::ShippingMethod', qbxml_class: 'ShipMethod', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
end
