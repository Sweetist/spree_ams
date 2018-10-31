module Spree::QboIntegration::Action::TxnClass
  def qbo_synchronize_transaction_class(txn_class_id)
    txn_class = self.vendor.txn_classes.find(txn_class_id)
    txn_class_hash = txn_class.to_integration(
        self.integration_item.integrationable_options_for(txn_class)
      )
    service = self.integration_item.qbo_service('Class')

    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: txn_class_hash.fetch(:id),
      integration_syncable_type: 'Spree::TransactionClass')
    if match.sync_id
      qbo_class = service.fetch_by_id(match.sync_id)
      qbo_update_class(qbo_class, txn_class_hash, service)
    else
      qbo_class = service.query("select * from Class where FullyQualifiedName='#{self.qbo_safe_string(txn_class_hash.fetch(:fully_qualified_name))}'").first
      if qbo_class
        # we have a match, save ID
        match.sync_id = qbo_class.id
        match.sync_type = qbo_class.class.to_s
        match.save
        qbo_update_class(qbo_class, txn_class_hash, service)
      elsif self.integration_item.qbo_create_related_objects

        qbo_new_class = qbo_class_to_qbo(
          Quickbooks::Model::Class.new,
          txn_class_hash
        )

        response = service.create(qbo_new_class)
        match.sync_id = response.id
        match.sync_type = response.class.to_s
        match.save
        { status: 10, log: "#{txn_class_hash.fetch(:name_for_integration)} => Pushed." }
      else
        { status: -1, log: "#{txn_class_hash.fetch(:name_for_integration)} => Unable to find Match for #{name}" }

      end
    end

  rescue Exception => e
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end

  def qbo_update_class(qbo_class, txn_class_hash, service)
    if qbo_class_update_required(qbo_class, txn_class_hash)
      qbo_updated_account = qbo_class_to_qbo(qbo_class, txn_class_hash)
      if self.integration_item.qbo_overwrite_conflicts_in == 'quickbooks'
        service.update(qbo_updated_account)
        { status: 10, log: "#{txn_class_hash.fetch(:name_for_integration)} => Match updated in QBO." }
      elsif self.integration_item.qbo_overwrite_conflicts_in == 'sweet'
        { status: 3, log: "#{txn_class_hash.fetch(:name_for_integration)} => Not currently supported"}
      else
        { status: 10, log: "#{txn_class_hash.fetch(:name_for_integration)} => No conflict resolution." }
      end
    else
      { status: 10, log: "#{txn_class_hash.fetch(:name_for_integration)} => Matched with no change" }
    end
  end

  def qbo_class_to_qbo(qbo_class, txn_class_hash)
    qbo_class.name = txn_class_hash.fetch(:name)
    if txn_class_hash.fetch(:parent_id).present?
        sync_parent = qbo_synchronize_transaction_class(txn_class_hash.fetch(:parent_id))
        if sync_parent.fetch(:status)
          parent = self.integration_item.integration_sync_matches.find_by(
            integration_syncable_id: txn_class_hash.fetch(:parent_id),
            integration_syncable_type: 'Spree::TransactionClass'
          )
        else
          return sync_parent
        end
      qbo_class.parent_ref = Quickbooks::Model::BaseReference.new(parent.try(:sync_id))
    end

    qbo_class
  end

  def qbo_class_update_required(qbo_class, txn_class_hash)
    qbo_class.try(:fully_qualified_name) != txn_class_hash.fetch(:fully_qualified_name)
  end


end
