module Spree::QbdIntegration::Action::TaxCategory
  #
  # Tax Category
  #
  def qbd_tax_category_step(tax_category_id, parent_step_id = nil)
    tax_category = Spree::TaxCategory.find(tax_category_id)
    tax_category_hash = tax_category.to_integration(
      self.integration_item.integrationable_options_for(tax_category)
    )

    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: tax_category_id, integration_syncable_type: 'Spree::TaxCategory')
    if match.sync_id.nil?
      next_step = { step_type: :query, object_id: tax_category_id, object_class: 'Spree::TaxCategory', qbxml_class: 'SalesTaxCode', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      next_step = { step_type: :create, object_id: tax_category_id, object_class: 'Spree::TaxCategory', qbxml_class: 'SalesTaxCode', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    else
      next_step = { step_type: :query, next_step: :skip, object_id: tax_category_id, object_class: 'Spree::TaxCategory', qbxml_class: 'SalesTaxCode', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    end

    tax_category_step = qbd_create_step(next_step, parent_step_id)

    # Sync Tax Rates
    tax_category_hash.fetch(:tax_rates, []).each do |tax_rate|
      rate_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: tax_rate.fetch(:id), integration_syncable_type: 'Spree::TaxRate')
      if rate_match.synced_at.nil? || rate_match.synced_at < Time.current - 10.minute
        qbd_create_step(
          self.qbd_tax_rate_step(rate_match.integration_syncable_id, tax_category_step.id),
          tax_category_step.id
        )
      end
    end

    sync_step = next_integration_step

    sync_step.try(:details) || next_step
  end

  def qbd_tax_category_to_sales_tax_code_xml(xml, tax_category_hash, match = nil)
    if match
      xml.ListID       match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Name           tax_category_hash.fetch(:code).slice(0..2) #CHAR LIMIT 3
    xml.IsTaxable      tax_category_hash.fetch(:tax_rates).any?{|rate| rate.fetch(:amount, 0) != 0}
    xml.Desc           tax_category_hash.fetch(:description, '').to_s.truncate(31)
  end

  def qbd_all_associated_matched_sales_tax_code?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/SalesTaxCodeQueryRs/SalesTaxCodeRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("SalesTaxCodeRet", {})

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_sales_tax_code_xml_to_tax_category(response, tax_category_hash)
    tax_category = self.company.tax_categories.find_by_id(tax_category_hash.fetch(:id, nil))
    xpath_base = '//QBXML/QBXMLMsgsRs/SalesTaxCodeQueryRs/SalesTaxCodeRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("SalesTaxCodeRet", {})
    qbd_sales_tax_category_hash_to_tax_category(qbd_hash, tax_category)

    return {}
  end

  def qbd_sales_tax_category_hash_to_tax_category(qbd_hash, tax_category = nil)
    code = qbd_hash.fetch('Name', nil)
    tax_category ||= self.company.tax_categories.where(
      'tax_code ilike ?', "#{code}"
    ).first

    return tax_category if tax_category.present?

    tax_category = self.company.tax_categories.create!(
      name: code,
      tax_code: code
    )
    qbd_create_or_update_match(tax_category,
                              'Spree::TaxCategory',
                              sync_id,
                              'SalesTaxCode',
                              qbd_hash.fetch('TimeCreated'),
                              qbd_hash.fetch('TimeModified'))

    tax_category
  end

  def qbd_tax_category_from_qbd_sales_tax_code(sync_id, code)
    return unless sync_id || code
    category_match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::TaxCategory',
      sync_id: sync_id
    ).first

    if category_match.try(:integration_syncable_id)
      tax_category = self.company.tax_categories.find_by_id(category_match.integration_syncable_id)
    end

    tax_category ||= self.company.tax_categories.where(
      'tax_code ilike ?', "#{code}"
    ).first
    if tax_category
      tax_category.tax_code = code
      tax_category.save
    elsif tax_category.nil? && code.present?
      tax_category = self.company.tax_categories.create!(
        name: code,
        tax_code: code
      )
    end
    raise "Unable to find tax category with code '#{code}'" if tax_category.nil?
    qbd_create_or_update_match(tax_category,
                              'Spree::TaxCategory',
                              sync_id,
                              'SalesTaxCode',
                              nil,
                              nil)
    tax_category
  end

  def qbd_find_tax_category_by_id_or_name(hash, base_key)
    qbd_tax_category_id = hash.fetch(base_key, {}).fetch('ListID', nil)
    qbd_tax_category_full_name = hash.fetch(base_key, {}).fetch('FullName', nil)
    return nil unless qbd_tax_category_id.present? || qbd_tax_category_full_name.present?

    match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::TaxCategory',
      sync_id: qbd_tax_category_id
    ).first

    tax_category = self.company.tax_categories.where(id: match.try(:integration_syncable_id)).first
    tax_category ||= self.company.tax_categories.where(
      'code ilike ?', "#{qbd_tax_category_full_name}%").first

    if tax_category.nil?
      sync_step = self.integration_steps.find_or_initialize_by(
        integrationable_type: 'Spree::TaxCategory',
        sync_type: 'SalesTaxCode',
        sync_id: qbd_tax_category_id
      )
      sync_step.parent_id ||= self.current_step.try(:id)
      sync_step.details = qbd_tax_category_pull_step_hash.merge(
        {'qbxml_query_by' => 'ListID', 'sync_id' => qbd_tax_category_id, 'sync_full_name' => qbd_tax_category_full_name}
      )

      sync_step.save
    end

    tax_category
  end

  def qbd_tax_category_pull_step_hash(tax_category_id = nil)
    { step_type: :pull, object_id: tax_category_id, object_class: 'Spree::TaxCategory', qbxml_class: 'SalesTaxCode', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end

end
