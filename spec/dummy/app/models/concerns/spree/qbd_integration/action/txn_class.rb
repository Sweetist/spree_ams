module Spree::QbdIntegration::Action::TxnClass

  def qbd_transaction_class_step(txn_class_id, parent_step_id = nil)
    txn_class = self.vendor.txn_classes.find(txn_class_id)
    txn_class_hash = txn_class.to_integration(
        self.integration_item.integrationable_options_for(txn_class)
      )

    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: txn_class_id, integration_syncable_type: 'Spree::TransactionClass')
    if match.sync_id.nil?
      next_step = { step_type: :query, object_id: txn_class_id, object_class: 'Spree::TransactionClass', qbxml_class: 'Class', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      next_step = { step_type: :create, object_id: txn_class_id, object_class: 'Spree::TransactionClass', qbxml_class: 'Class', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    else
      if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = qbd_txn_class_push_step_hash(txn_class_id)
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        next_step = qbd_txn_class_pull_step_hash(txn_class_id)
      else
        next_step = { step_type: :query, next_step: :skip, object_id: txn_class_id, object_class: 'Spree::TransactionClass', qbxml_class: 'Class', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
      end
    end

    if txn_class_hash.fetch(:parent_id)
      child_class_step = qbd_create_step(next_step)
      parent_match = self.integration_item.integration_sync_matches.find_or_create_by(
        integration_syncable_id: txn_class_hash.fetch(:parent_id),
        integration_syncable_type: 'Spree::TransactionClass'
      )
      if parent_match.synced_at.nil? || parent_match.synced_at < Time.current - 10.minute
        parent_class_step = qbd_create_step(
          self.qbd_transaction_class_step(txn_class_hash.fetch(:parent_id), child_class_step.try(:id))
        )
        next_step = parent_class_step.details
        # return self.qbd_transaction_class_step(txn_class_hash.fetch(:parent_id))
      end
    end

    next_step
  end

  def qbd_transaction_class_to_class_xml(xml, txn_class_hash, match = nil)
    if match
      xml.ListID       match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Name          txn_class_hash.fetch(:name)
    if txn_class_hash.fetch(:parent_id).present?
      parent_match = self.integration_item.integration_sync_matches.find_by(
        integration_syncable_type: 'Spree::TransactionClass',
        integration_syncable_id: txn_class_hash.fetch(:parent_id)
      )
      xml.ParentRef do
        xml.ListID  parent_match.try(:sync_id)
      end
    end
  end

  def qbd_all_associated_matched_class?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/ClassQueryRs/ClassRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ClassRet", {})

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_class_xml_to_transaction_class(response, txn_class_hash)
    txn_class = self.company.transaction_classes.find_by_id(txn_class_hash.fetch(:id, nil))
    xpath_base = '//QBXML/QBXMLMsgsRs/ClassQueryRs/ClassRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("ClassRet", {})
    qbd_class_hash_to_transaction_class(qbd_hash, txn_class)
    # {
    #   # name: response.xpath("#{xpath_base}/Name").try(:children).try(:text)
    # }.delete_if { |k, v| v.blank? }

    return {}
  end

  def qbd_class_hash_to_transaction_class(qbd_hash, txn_class = nil)
    full_name = qbd_hash.fetch('FullName', nil)
    txn_class ||= self.company.transaction_classes.where(
      fully_qualified_name: full_name
    ).first

    if txn_class.present?
      txn_class.name = qbd_hash.fetch('Name', '')
      txn_class.save

      return txn_class
    end

    parent_full_name = qbd_hash.fetch('ParentRef', {}).fetch('FullName', nil)
    if parent_full_name.present?
      parent_txn_class = self.company.transaction_classes.where(
        fully_qualified_name: parent_full_name
      ).first
      if parent_txn_class.present?
        #Create txn_class
        txn_class = qbd_create_transaction_class_from_class_hash(qbd_hash)
      else
        #Create parent step
        parent_sync_id = qbd_hash.fetch('ParentRef', {}).fetch('ListID', nil)
        sync_step = self.integration_steps.find_or_initialize_by(
          integrationable_type: 'Spree::TransactionClass',
          sync_type: 'Class',
          sync_id: parent_sync_id
        )
        sync_step.master = self.integration_item.qbd_create_related_objects ? 'quickbooks' : 'none'
        sync_step.parent_id = self.current_step.try(:id)
        sync_step.details = qbd_txn_class_pull_step_hash.merge(
          {'qbxml_query_by' => 'ListID','sync_id' => parent_sync_id, 'sync_full_name' => parent_full_name}
        )
        sync_step.save!
      end
    else
      #Create txn_class
      txn_class = qbd_create_transaction_class_from_class_hash(qbd_hash)
    end

    qbd_create_or_update_match(txn_class,
                              'Spree::TransactionClass',
                              qbd_hash.fetch('ListID'),
                              'Class',
                              qbd_hash.fetch('TimeCreated'),
                              qbd_hash.fetch('TimeModified'),
                              qbd_hash.fetch('EditSequence', nil))

    txn_class
  end

  def qbd_create_transaction_class_from_class_hash(qbd_hash)
    full_name = qbd_hash.fetch('FullName', nil)
    parent_full_name = qbd_hash.fetch('ParentRef', {}).fetch('FullName', nil)

    txn_class = self.company.transaction_classes.new(name: qbd_hash.fetch('Name', nil))

    if parent_full_name.present?
      parent_txn_class = self.company.transaction_classes.where(
        fully_qualified_name: parent_full_name
      ).first

      raise "Unable to find Class #{parent_full_name}" unless parent_txn_class.present?
      txn_class.parent_id = parent_txn_class.try(:id)
    end

    txn_class.save!
  end

  def qbd_find_transaction_class_by_id_or_name(hash, base_key)
    qbd_class_id = hash.fetch(base_key, {}).fetch('ListID', nil)
    qbd_class_full_name = hash.fetch(base_key, {}).fetch('FullName', nil)
    return nil unless qbd_class_id.present? || qbd_class_full_name.present?

    class_match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::TransactionClass',
      sync_id: qbd_class_id
    ).first

    txn_class = self.company.txn_classes.where(id: class_match.try(:integration_syncable_id)).first
    txn_class ||= self.company.txn_classes.where(fully_qualified_name: qbd_class_full_name).first

    if txn_class.nil?
      sync_step = self.integration_steps.find_or_initialize_by(
        integrationable_type: 'Spree::TransactionClass',
        sync_type: 'Class',
        sync_id: qbd_class_id
      )
      sync_step.parent_id ||= self.current_step.try(:id)
      sync_step.details = qbd_txn_class_pull_step_hash.merge(
        {'qbxml_query_by' => 'ListID', 'sync_id' => qbd_class_id, 'sync_full_name' => qbd_class_full_name}
      )

      sync_step.save
    end

    txn_class
  end

  def qbd_txn_class_pull_step_hash(txn_class_id = nil)
    { step_type: :pull, object_id: txn_class_id, object_class: 'Spree::TransactionClass', qbxml_class: 'Class', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  def qbd_txn_class_push_step_hash(txn_class_id = nil)
    { step_type: :push, object_id: txn_class_id, object_class: 'Spree::TransactionClass', qbxml_class: 'Class', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
end
