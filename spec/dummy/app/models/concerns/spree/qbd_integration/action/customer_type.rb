module Spree::QbdIntegration::Action::CustomerType
  #
  # Customer Type
  #
  def qbd_customer_type_step(customer_type_id, parent_step_id = nil)
    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: customer_type_id, integration_syncable_type: 'Spree::CustomerType')
    if match.sync_id.nil?
      next_step = { step_type: :query, object_id: customer_type_id, object_class: 'Spree::CustomerType', qbxml_class: 'CustomerType', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      next_step = { step_type: :create, object_id: customer_type_id, object_class: 'Spree::CustomerType', qbxml_class: 'CustomerType', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    else
      if self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = { step_type: :query, next_step: :skip, object_id: customer_type_id, object_class: 'Spree::CustomerType', qbxml_class: 'CustomerType', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
        # There is not Mod type xml for customer types. You can only Add or Query
        # { step_type: :push, object_id: customer_type_id, object_class: 'Spree::CustomerType', qbxml_class: 'CustomerType', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        next_step = qbd_customer_type_pull_step_hash(customer_type_id)
      else
        next_step = { step_type: :query, next_step: :skip, object_id: customer_type_id, object_class: 'Spree::CustomerType', qbxml_class: 'CustomerType', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
      end
    end

    next_step
  end

  def qbd_customer_type_to_customer_type_xml(xml, customer_type_hash, match = nil)
    if match
      xml.ListID       match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Name           customer_type_hash.fetch(:name)
    if customer_type_hash.fetch(:parent_fully_qualifed_name).present?
      xml.ParentRef do
        xml.FullName  customer_type_hash.fetch(:parent_fully_qualifed_name)
      end
    end
  end

  def qbd_all_associated_matched_customer_type?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/CustomerTypeQueryRs/CustomerTypeRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("CustomerTypeRet", {})

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_customer_type_xml_to_customer_type(response, customer_type_hash)
    customer_type = self.company.customer_types.find_by_id(customer_type_hash.fetch(:id, nil))
    xpath_base = '//QBXML/QBXMLMsgsRs/CustomerTypeQueryRs/CustomerTypeRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("CustomerTypeRet", {})
    qbd_customer_type_hash_to_customer_type(qbd_hash, customer_type)
    # {
    #   # name: response.xpath("#{xpath_base}/Name").try(:children).try(:text)
    # }.delete_if { |k, v| v.blank? }
    return {}
  end

  def qbd_customer_type_hash_to_customer_type(qbd_hash, customer_type = nil)
    full_name = qbd_hash.fetch('FullName', nil)
    # TODO support nested customer types with fully_qualified_name
    customer_type ||= self.company.customer_types.find_or_create_by(
      name: full_name
    )

    customer_type
  end

  def qbd_find_customer_type_by_id_or_name(hash, base_key)
    qbd_customer_type_id = hash.fetch(base_key, {}).fetch('ListID', nil)
    qbd_customer_type_full_name = hash.fetch(base_key, {}).fetch('FullName', nil)
    return nil unless qbd_customer_type_id.present? || qbd_customer_type_full_name.present?

    match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::CustomerType',
      sync_id: qbd_customer_type_id
    ).first

    customer_type = self.company.customer_types.where(id: match.try(:integration_syncable_id)).first
    customer_type ||= self.company.customer_types.where(name: qbd_customer_type_full_name).first

    if customer_type.nil?
      sync_step = self.integration_steps.find_or_initialize_by(
        integrationable_type: 'Spree::CustomerType',
        sync_type: 'CustomerType',
        sync_id: qbd_customer_type_id
      )
      sync_step.parent_id ||= self.current_step.try(:id)
      sync_step.details = qbd_customer_type_pull_step_hash.merge(
        {'qbxml_query_by' => 'ListID', 'sync_id' => qbd_customer_type_id, 'sync_full_name' => qbd_customer_type_full_name}
      )

      sync_step.save
    end

    customer_type
  end

  def qbd_customer_type_pull_step_hash(customer_type_id = nil)
    { step_type: :pull, object_id: customer_type_id, object_class: 'Spree::CustomerType', qbxml_class: 'CustomerType', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end

end
