module Spree::QbdIntegration::Action::Rep
  #
  # Rep
  #
  def qbd_rep_step(rep_id, parent_step_id = nil)
    rep = self.company.reps.find(rep_id)
    if self.company.reps.where('initials ilike ?', rep.initials).count > 1
      raise "Sales Rep initials '#{rep.initials}' for #{rep.name} must be unique."
    end

    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: rep_id, integration_syncable_type: 'Spree::Rep', sync_type: 'SalesRep')
    if match.sync_id.nil?
      next_step = qbd_sales_rep_query_step_hash(rep_id)
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      # Sync OtherName
      next_step = qbd_sales_rep_create_step_hash(rep_id)
      other_name_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: rep_id, integration_syncable_type: 'Spree::Rep', sync_type: 'OtherName')
      if other_name_match.synced_at.nil? || other_name_match.synced_at < Time.current - 2.minute
        parent_step = qbd_create_step(
          next_step
        )
        # return
        # qbd_create_step(
          return self.qbd_rep_other_name_step(rep_id, parent_step.try(:id))
        # )
      end
    else
      if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = qbd_sales_rep_push_step_hash(rep_id)
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        next_step = qbd_sales_rep_pull_step_hash(rep_id)
      else
        next_step = qbd_sales_rep_query_step_hash(rep_id).merge({next_step: :skip})
      end
    end

    # qbd_create_step(next_step).make_current
    # self.reload
    # debugger
    # sync_step = self.current_step.sub_steps.incomplete.order(id: :desc).first
    # sync_step.try(:make_current)

    # sync_step.try(:details) || next_step
    next_step
  end

  def qbd_rep_to_sales_rep_xml(xml, rep_hash, match = nil)
    if match
      xml.ListID       match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Initial        rep_hash.fetch(:initials)

    other_name_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: rep_hash.fetch(:id), integration_syncable_type: 'Spree::Rep', sync_type: 'OtherName')
    if other_name_match.try(:sync_id)
      xml.SalesRepEntityRef do
        xml.ListID       other_name_match.sync_id
      end
    end
  end

  def qbd_all_associated_matched_sales_rep?(response, rep_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/SalesRepQueryRs/SalesRepRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("SalesRepRet", {})
    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_sales_rep_xml_to_rep(response, rep_hash)
    rep = self.company.reps.find_by_id(rep_hash.fetch(:id, nil))
    xpath_base = '//QBXML/QBXMLMsgsRs/SalesRepQueryRs/SalesRepRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("SalesRepRet", {})
    qbd_sales_rep_hash_to_rep(qbd_hash, rep)
    {
      # name: response.xpath("#{xpath_base}/SalesRepEntityRef/FullName").try(:children).try(:text)
      # initials: response.xpath("#{xpath_base}/Initial").try(:children).try(:text)
    }.delete_if { |k, v| v.blank? }
  end

  def qbd_sales_rep_hash_to_rep(qbd_hash, rep = nil)
    full_name = qbd_hash.fetch('SalesRepEntityRef', {}).fetch('FullName', '')
    rep ||= self.company.reps.find_or_initialize_by(
      name: full_name
    )
    rep.name = full_name
    rep.initials = qbd_hash.fetch('Initial', '')
    rep.save

    qbd_create_or_update_match(rep,
                              'Spree::Rep',
                              qbd_hash.fetch('ListID'),
                              'SalesRep',
                              qbd_hash.fetch('TimeCreated'),
                              qbd_hash.fetch('TimeModified'),
                              qbd_hash.fetch('EditSequence', nil))

    rep
  end

  def qbd_find_rep_by_id_or_name(hash, base_key)
    qbd_sales_rep_id = hash.fetch(base_key, {}).fetch('ListID', nil)
    qbd_sales_rep_full_name = hash.fetch(base_key, {}).fetch('FullName', nil)
    return nil unless qbd_sales_rep_id.present? || qbd_sales_rep_full_name.present?

    match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::Rep',
      sync_id: qbd_sales_rep_id,
      sync_type: 'SalesRep'
    ).first

    rep = self.company.reps.where(id: match.try(:integration_syncable_id)).first
    rep ||= self.company.reps.where(initials: qbd_sales_rep_full_name).first

    if rep.nil?
      sync_step = self.integration_steps.find_or_initialize_by(
        integrationable_type: 'Spree::SalesRep',
        sync_type: 'SalesRep',
        sync_id: qbd_sales_rep_id
      )
      sync_step.parent_id ||= self.current_step.try(:id)
      sync_step.details = qbd_sales_rep_pull_step_hash.merge(
        {'qbxml_query_by' => 'ListID', 'sync_id' => qbd_sales_rep_id, 'sync_full_name' => qbd_sales_rep_full_name}
      )

      sync_step.save
    end

    rep
  end

  def qbd_sales_rep_query_step_hash(rep_id = nil)
    { step_type: :query, object_id: rep_id, object_class: 'Spree::Rep', sync_type: 'SalesRep', qbxml_class: 'SalesRep', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  def qbd_sales_rep_create_step_hash(rep_id = nil)
    { step_type: :create, object_id: rep_id, object_class: 'Spree::Rep', sync_type: 'SalesRep', qbxml_class: 'SalesRep', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  def qbd_sales_rep_push_step_hash(rep_id = nil)
    { step_type: :push, object_id: rep_id, object_class: 'Spree::Rep', sync_type: 'SalesRep', qbxml_class: 'SalesRep', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  def qbd_sales_rep_pull_step_hash(rep_id = nil)
    { step_type: :pull, object_id: rep_id, object_class: 'Spree::Rep', sync_type: 'SalesRep', qbxml_class: 'SalesRep', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  #
  # Other Name
  #
  def qbd_rep_other_name_step(rep_id, parent_step_id = nil)
    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: rep_id, integration_syncable_type: 'Spree::Rep', sync_type: 'OtherName')
    if match.sync_id.nil?
      { step_type: :query, object_id: rep_id, object_class: 'Spree::Rep', sync_type: 'OtherName', qbxml_class: 'OtherName', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      { step_type: :create, next_step: :continue, object_id: rep_id, object_class: 'Spree::Rep', sync_type: 'OtherName', qbxml_class: 'OtherName', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    else
      if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        { step_type: :push, next_step: :continue, object_id: rep_id, object_class: 'Spree::Rep', sync_type: 'OtherName', qbxml_class: 'OtherName', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        { step_type: :pull, next_step: :continue, object_id: rep_id, object_class: 'Spree::Rep', sync_type: 'OtherName', qbxml_class: 'OtherName', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
      else
        { step_type: :query, next_step: :skip, object_id: rep_id, object_class: 'Spree::Rep', sync_type: 'OtherName', qbxml_class: 'OtherName', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
      end
    end
  end

  def qbd_all_associated_matched_other_name?(response, object_hash)
    true #no other items to create/update
  end

  def qbd_rep_to_other_name_xml(xml, other_name_hash, match = nil)
    if match
      xml.ListID       match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Name        other_name_hash.fetch(:name)
  end

  def qbd_other_name_xml_to_rep(response, other_name_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/OtherNameQueryRs/OtherNameRet'
    {
      name: response.xpath("#{xpath_base}/Name").try(:children).try(:text)
    }.delete_if { |k, v| v.blank? }
  end

end
