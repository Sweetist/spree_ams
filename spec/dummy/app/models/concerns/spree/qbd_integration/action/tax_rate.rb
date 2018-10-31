module Spree::QbdIntegration::Action::TaxRate
  #
  # Tax Rate
  #
  def qbd_tax_rate_step(tax_rate_id, parent_step_id = nil)
    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: tax_rate_id, integration_syncable_type: 'Spree::TaxRate')
    if match.sync_id.nil?
      next_step = { step_type: :query, object_id: tax_rate_id, object_class: 'Spree::TaxRate', qbxml_class: 'ItemSalesTax', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      next_step = { step_type: :create, object_id: tax_rate_id, object_class: 'Spree::TaxRate', qbxml_class: 'ItemSalesTax', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    else
      if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = { step_type: :push, object_id: tax_rate_id, object_class: 'Spree::TaxRate', qbxml_class: 'ItemSalesTax', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        next_step = { step_type: :pull, object_id: tax_rate_id, object_class: 'Spree::TaxRate', qbxml_class: 'ItemSalesTax', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
      else
        next_step = { step_type: :query, next_step: :skip, object_id: tax_rate_id, object_class: 'Spree::TaxRate', qbxml_class: 'ItemSalesTax', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
      end
    end

    next_step
  end

  def qbd_tax_rate_to_item_sales_tax_xml(xml, tax_rate_hash, match = nil)
    if match
      xml.ListID       match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Name           tax_rate_hash.fetch(:name)
    xml.TaxRate        tax_rate_hash.fetch(:amount) * 100
    # unless tax_rate_hash.fetch(:amount) == 0
      xml.TaxVendorRef do
        xml.FullName     tax_rate_hash.fetch(:zone_name)
      end
    # end
  end

  def qbd_all_associated_matched_item_sales_tax?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/ItemSalesTaxQueryRs/ItemSalesTaxRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ItemSalesTaxRet", {})

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_item_sales_tax_xml_to_tax_rate(response, tax_rate_hash)
    tax_rate = self.company.tax_rates.find_by_id(tax_rate_hash.fetch(:id, nil))
    xpath_base = '//QBXML/QBXMLMsgsRs/ItemSalesTaxQueryRs/ItemSalesTaxRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ItemSalesTaxRet", {})
    qbd_item_sales_tax_hash_to_tax_rate(qbd_hash, tax_rate)

    return {}
  end

  def qbd_item_sales_tax_hash_to_tax_rate(qbd_hash, tax_rate = nil)
    tax_rate ||= self.company.tax_rates.where(
      name: qbd_hash.fetch('Name', nil)
    ).first

    raise "Unable to find tax rate '#{qbd_hash.fetch('Name', nil)}' in Sweet." unless tax_rate.present?

    tax_rate
  end

  def qbd_find_tax_rate_by_id_or_name(hash, base_key)
    qbd_tax_rate_id = hash.fetch(base_key, {}).fetch('ListID', nil)
    qbd_tax_rate_full_name = hash.fetch(base_key, {}).fetch('FullName', nil)
    return nil unless qbd_tax_rate_id.present? || qbd_tax_rate_full_name.present?

    match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::tax_rate',
      sync_id: qbd_tax_rate_id
    ).first

    tax_rate = self.company.tax_rates.where(id: match.try(:integration_syncable_id)).first
    tax_rate ||= self.company.tax_rates.where(name: qbd_tax_rate_full_name).first

    if tax_rate.nil?
      sync_step = self.integration_steps.find_or_initialize_by(
        integrationable_type: 'Spree::Rate',
        sync_type: 'ItemSalesTaxRef',
        sync_id: qbd_tax_rate_id
      )
      sync_step.parent_id ||= self.current_step.try(:id)
      sync_step.details = qbd_tax_rate_pull_step_hash.merge(
        {'qbxml_query_by' => 'ListID', 'sync_id' => qbd_tax_rate_id, 'sync_full_name' => qbd_tax_rate_full_name}
      )

      sync_step.save
    end

    tax_rate
  end

  def qbd_tax_rate_pull_step_hash(tax_rate_id = nil)
    { step_type: :pull, object_id: tax_rate_id, object_class: 'Spree::TaxRate', qbxml_class: 'ItemSalesTax', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end

end
