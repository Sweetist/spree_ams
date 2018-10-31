module Spree::QbdIntegration::Action::StockLocation
  #
  # Stock Location
  #
  def qbd_stock_location_step(stock_location_id, parent_step_id = nil)
    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: stock_location_id, integration_syncable_type: 'Spree::StockLocation')
    if match.sync_id.nil?
      { step_type: :query, object_id: stock_location_id, object_class: 'Spree::StockLocation', qbxml_class: 'InventorySite', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      { step_type: :create, object_id: stock_location_id, object_class: 'Spree::StockLocation', qbxml_class: 'InventorySite', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    else
      if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        { step_type: :push, object_id: stock_location_id, object_class: 'Spree::StockLocation', qbxml_class: 'InventorySite', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        { step_type: :pull, object_id: stock_location_id, object_class: 'Spree::StockLocation', qbxml_class: 'InventorySite', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
      else
        { step_type: :query, next_step: :skip, object_id: stock_location_id, object_class: 'Spree::StockLocation', qbxml_class: 'InventorySite', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
      end
    end
  end

  def qbd_stock_location_to_inventory_site_xml(xml, stock_location_hash, match = nil)
    if match
      xml.ListID       match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Name           stock_location_hash.fetch(:name)
  end

  def qbd_inventory_site_xml_to_stock_location(response, stock_location_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/InventorySiteQueryRs/InventorySiteRet'
    {
      # name: response.xpath("#{xpath_base}/Name").try(:children).try(:text)
    }.delete_if { |k, v| v.blank? }
  end

  def qbd_all_associated_matched_inventory_site?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/InventorySiteQueryRs/InventorySiteRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("InventorySiteRet", {})

    qbd_inventory_site_find_or_assign_associated_opts(qbd_hash)

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_inventory_site_find_or_assign_associated_opts(qbd_hash, stock_location = nil)

  end

end
