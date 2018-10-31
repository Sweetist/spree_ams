module Spree::QbdIntegration::Action::Vendor
  #
  # Account
  #
  def qbd_vendor_step(account_id, parent_step_id = nil)
    account_hash = Spree::Account.find(account_id).to_integration
    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_id, integration_syncable_type: 'Spree::Account')

    unless self.integration_steps.where(integrationable_type: 'Spree::Account', integration_syncable_id: account_id).first || self.current_step.present?
      next_step = qbd_vendor_query_step_hash(account_id).merge({next_step: :continue})
      next_step.merge!({qbxml_query_by: 'ListID', sync_id: match.sync_id}) if match.sync_id.present?
      next_step = qbd_create_step(next_step, parent_step_id)
      next_step.update_columns(sync_id: match.sync_id)
      return next_step.details
    end
    # Sync Account
    if match.sync_id.nil?
      next_step = qbd_vendor_query_step_hash(account_id)
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      next_step = qbd_vendor_create_step_hash(account_id)
    else
      if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = qbd_vendor_push_step_hash(account_id)
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        next_step = qbd_vendor_pull_step_hash(account_id)
      else
        next_step = qbd_vendor_query_step_hash(account_id).merge({next_step: :skip})
      end
    end

    acc_step = qbd_create_step(next_step, parent_step_id)
    # Sync Payment Terms
    if account_hash.fetch(:account, {}).fetch(:payment_term_id)
      payment_term_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account, {}).fetch(:payment_term_id), integration_syncable_type: 'Spree::PaymentTerm')
      if payment_term_match.synced_at.nil? # sync PaymentTerm only to Query & Create
        qbd_create_step(
          self.qbd_payment_term_step(payment_term_match.integration_syncable_id),
          acc_step.try(:id)
        )
      end
    end
    # Sync Vendor Type
    # NOTE: vendor type is not currently supported in Sweet - Mar 2018
    # if account_hash.fetch(:account, {}).fetch(:vendor_type_id)
    #   vendor_type_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account, {}).fetch(:vendor_type_id), integration_syncable_type: 'Spree::VendorType')
    #   if vendor_type_match.synced_at.nil? || vendor_type_match.synced_at < Time.current #- 2.minute
    #     qbd_create_step(
    #       self.qbd_vendor_type_step(vendor_type_match.integration_syncable_id),
    #       acc_step.try(:id)
    #     )
    #   end
    # end

    #Sync TxnClass
    if self.integration_item.qbd_sync_customer_class? && account_hash.fetch(:account, {}).fetch(:txn_class_id)
      txn_class_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account, {}).fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
      if txn_class_match.synced_at.nil? || txn_class_match.synced_at < Time.current #- 2.minute
        qbd_create_step(
          self.qbd_transaction_class_step(txn_class_match.integration_syncable_id),
          acc_step.try(:id)
        )
      end
    end

    sync_step = next_integration_step

    sync_step.try(:details) || next_step
  end

  def qbd_account_to_vendor_xml(xml, account_hash, match = nil)
    account = account_hash.fetch(:account,{})

    # Build XML
    if match
      xml.ListID       match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Name           account.fetch(:name)
    xml.IsActive       account.fetch(:active)

    if self.integration_item.qbd_sync_customer_class?
      txn_class_id = account.fetch(:txn_class_id)
      if txn_class_id
        txn_class_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: txn_class_id, integration_syncable_type: 'Spree::TransactionClass')
        xml.ClassRef do
          xml.ListID     txn_class_match.try(:sync_id)
        end
      end
    end

    xml.CompanyName    account.fetch(:name)
    xml.FirstName      account.fetch(:firstname)
    xml.LastName       account.fetch(:lastname)
    xml.VendorAddress do
      qbd_address_to_address_xml(xml, account_hash.fetch(:bill_address, {}))
    end
    xml.ShipAddress do
      qbd_address_to_address_xml(xml, account_hash.fetch(:ship_address, {}))
    end
    xml.Phone          account_hash.fetch(:ship_address, {}).fetch(:phone, '').to_s
    xml.Email          account.fetch(:email, '').to_s

    # NOTE: vendor type is not currently supported in Sweet - Mar 2018
    # vendor_type_id = account.fetch(:vendor_type_id, nil)
    # if vendor_type_id
    #   vendor_type_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: vendor_type_id, integration_syncable_type: 'Spree::VendorType')
    #   xml.VendorTypeRef do
    #     xml.ListID     vendor_type_match.try(:sync_id)
    #   end
    # end

    payment_term_id = account.fetch(:payment_term_id)
    if payment_term_id
      payment_term_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: payment_term_id, integration_syncable_type: 'Spree::PaymentTerm')
      xml.TermsRef do
        xml.ListID     payment_term_match.try(:sync_id)
      end
    end

    # Return XML
    xml
  end

  def qbd_vendor_xml_to_account(response, account_hash)
    account = self.company.vendor_accounts.find_by_id(account_hash.fetch(:account, {}).fetch(:id, nil))
    xpath_base = '//QBXML/QBXMLMsgsRs/VendorQueryRs/VendorRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("VendorRet", {})
    qbd_vendor_hash_to_account(qbd_hash, account)

    # Need to return a hash because calling method is expecting hash of attributes to update
    return {}
  end

  def qbd_all_associated_matched_vendor?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/VendorQueryRs/VendorRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("VendorRet", {})

    qbd_vendor_find_or_assign_associated_opts(qbd_hash)

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_vendor_find_or_assign_associated_opts(qbd_hash, account = nil)

    if self.integration_item.qbd_sync_customer_class?
      txn_class = qbd_find_transaction_class_by_id_or_name(qbd_hash, 'ClassRef')
    end
    # vendor_type = qbd_find_vendor_type_by_id_or_name(qbd_hash, 'VendorTypeRef') # NOTE not supported - Mar 2018
    payment_term = qbd_find_payment_term_by_id_or_name(qbd_hash, 'TermsRef')
    balance = qbd_hash.fetch('Balance', nil)
    if account
      # account.vendor_type_id = vendor_type.try(:id) # NOTE not supported - Mar 2018
      account.payment_terms_id = payment_term.try(:id)
      account.balance = balance unless balance.nil?

      if self.integration_item.qbd_sync_customer_class?
        account.default_txn_class_id = txn_class.try(:id)
      end

    end
  end

  def qbd_vendor_hash_to_account(qbd_hash, account = nil)
    if account.nil?
      vendor_company = self.integration_item.company.vendors.where(
        name: qbd_hash.fetch('FullName', '').split(':').first
      ).first
      vendor_company ||= Spree::Company.new(name: qbd_hash.fetch('FullName', '').split(':').first)
      vendor_company.save!
      account = Spree::Account.new(
        vendor_id: vendor_company.id,
        customer_id: self.integration_item.company_id
      )
    end
    bill_addr_hash = qbd_hash.fetch('VendorAddress', {})
    ship_addr_hash = qbd_hash.fetch('ShipAddress', {})
    qbd_address_hash_to_address(bill_addr_hash, account, 'billing', account.bill_address)
    qbd_address_hash_to_address(ship_addr_hash, account, 'shipping', account.default_ship_address)
    account.email = qbd_hash.fetch('Email', '')
    account.name = qbd_hash.fetch('Name', '') if qbd_hash.fetch('Name', '').present?

    qbd_vendor_find_or_assign_associated_opts(qbd_hash, account)
    if account.id.nil?
      qbd_find_or_build_match(account,
                              'Spree::Account',
                              qbd_hash.fetch('ListID'),
                              'Vendor',
                              qbd_hash.fetch('TimeCreated'),
                              qbd_hash.fetch('TimeModified'),
                              qbd_hash.fetch('EditSequence', nil))
    else
      qbd_create_or_update_match(account,
                                'Spree::Account',
                                qbd_hash.fetch('ListID'),
                                'Vendor',
                                qbd_hash.fetch('TimeCreated'),
                                qbd_hash.fetch('TimeModified'),
                                qbd_hash.fetch('EditSequence', nil))
    end

    account.save!
  end

  def qbd_vendor_query_step_hash(account_id = nil)
    { step_type: :query, object_id: account_id, object_class: 'Spree::Account', qbxml_class: 'Vendor', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  def qbd_vendor_create_step_hash(account_id = nil)
    { step_type: :create, object_id: account_id, object_class: 'Spree::Account', qbxml_class: 'Vendor', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  def qbd_vendor_pull_step_hash(account_id = nil)
    { step_type: :pull, object_id: account_id, object_class: 'Spree::Account', qbxml_class: 'Vendor', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  def qbd_vendor_push_step_hash(account_id = nil)
    { step_type: :push, object_id: account_id, object_class: 'Spree::Account', qbxml_class: 'Vendor', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end

  def qbd_vendor_next_step_hash(account_id = nil)
    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_id, integration_syncable_type: 'Spree::Account')
    if match.sync_id.nil?
      next_step = qbd_vendor_query_step_hash(account_id)
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      next_step = qbd_vendor_create_step_hash(account_id)
    else
      if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = qbd_vendor_push_step_hash(account_id)
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        next_step = qbd_vendor_pull_step_hash(account_id)
      else
        next_step = qbd_vendor_query_step_hash(account_id).merge({next_step: :skip})
      end
    end

    next_step
  end

end
