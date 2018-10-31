module Spree::QbdIntegration::Action::Account
  #
  # Account
  #
  def qbd_account_step(account_id, parent_step_id = nil, is_parent = false)
    account = Spree::Account.find(account_id)
    if account.customer_id == self.company.id
      return qbd_vendor_step(account_id, parent_step_id)
    end

    account_hash = account.to_integration(
      self.integration_item.integrationable_options_for(account)
    )
    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: account_id,
      integration_syncable_type: 'Spree::Account'
    )

    unless self.integration_steps.where(integrationable_type: 'Spree::Account', integration_syncable_id: account_id).first || self.current_step.present? || parent_step_id
      next_step = qbd_account_query_step_hash(account_id).merge({next_step: :continue})
      next_step.merge!({qbxml_query_by: 'ListID', sync_id: match.sync_id}) if match.sync_id.present?
      next_step = qbd_create_step(next_step, parent_step_id)
      next_step.update_columns(sync_id: match.sync_id)
      return next_step.details
    end
    # Sync Account
    if match.sync_id.nil?
      next_step = qbd_account_query_step_hash(account_id)
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      next_step = qbd_account_create_step_hash(account_id)
    else
      if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = qbd_account_push_step_hash(account_id)
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        next_step = qbd_account_pull_step_hash(account_id)
      else
        next_step = qbd_account_query_step_hash(account_id).merge({next_step: is_parent ? :continue : :skip})
      end
    end

    acc_step = qbd_create_step(next_step, parent_step_id)
    self.reload

    # Sync Payment Terms
    if account_hash.fetch(:account, {}).fetch(:payment_term_id)
      payment_term_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account, {}).fetch(:payment_term_id), integration_syncable_type: 'Spree::PaymentTerm')
      if payment_term_match.synced_at.nil? # sync PaymentTerm only to Query & Create
        qbd_create_step(
          self.qbd_payment_term_step(payment_term_match.integration_syncable_id, acc_step.id),
          acc_step.id
        )
      end
    end
    # Sync Customer Type
    if account_hash.fetch(:account, {}).fetch(:customer_type_id)
      customer_type_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account, {}).fetch(:customer_type_id), integration_syncable_type: 'Spree::CustomerType')
      if customer_type_match.synced_at.nil? || customer_type_match.synced_at < Time.current #- 2.minute
        qbd_create_step(
          self.qbd_customer_type_step(customer_type_match.integration_syncable_id, acc_step.id),
          acc_step.try(:id)
        )
      end
    end
    # Sync Rep
    if account_hash.fetch(:account, {}).fetch(:rep_id)
      rep_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account, {}).fetch(:rep_id), integration_syncable_type: 'Spree::Rep', sync_type: 'SalesRep')
      if rep_match.synced_at.nil? || rep_match.synced_at < Time.current #- 2.minute
        qbd_create_step(
          self.qbd_rep_step(rep_match.integration_syncable_id, acc_step.id),
          acc_step.try(:id)
        )
      end
    end

    #Sync TxnClass
    if self.integration_item.qbd_sync_customer_class? && account_hash.fetch(:account, {}).fetch(:txn_class_id)
      txn_class_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account, {}).fetch(:txn_class_id), integration_syncable_type: 'Spree::TransactionClass')
      if txn_class_match.synced_at.nil? || txn_class_match.synced_at < Time.current #- 2.minute
        qbd_create_step(
          self.qbd_transaction_class_step(txn_class_match.integration_syncable_id, acc_step.id),
          acc_step.try(:id)
        )
      end
    end

    if account_hash.fetch(:account, {}).fetch(:sub_customer, nil)
      parent_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_hash.fetch(:account, {}).fetch(:parent_id), integration_syncable_type: 'Spree::Account', sync_type: 'Customer')
      if parent_match.synced_at.nil? || parent_match.synced_at < Time.current #- 2.minute
        qbd_create_step(
          self.qbd_account_step(parent_match.integration_syncable_id, acc_step.try(:id), true),
          acc_step.try(:id)
        )
      end
    end

    sync_step = next_integration_step
    sync_step.try(:details) || next_step
  end

  def qbd_account_to_customer_xml(xml, account_hash, match = nil)
    account = account_hash.fetch(:account,{})
    if account.fetch(:sub_customer, nil)
      parent_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account.fetch(:parent_id), integration_syncable_type: 'Spree::Account', sync_type: 'Customer')
    end
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

    if account_hash.fetch(:account, {}).fetch(:sub_customer, nil)
      xml.ParentRef do
        xml.ListID  parent_match.try(:sync_id)
      end
    end

    xml.CompanyName    account.fetch(:name)
    xml.FirstName      account.fetch(:firstname)
    xml.LastName       account.fetch(:lastname)
    xml.BillAddress do
      qbd_address_to_address_xml(xml, account_hash.fetch(:bill_address, {}))
    end
    xml.ShipAddress do
      qbd_address_to_address_xml(xml, account_hash.fetch(:ship_address, {}))
    end
    xml.Phone          account_hash.fetch(:ship_address, {}).fetch(:phone, '').to_s
    xml.Email          account.fetch(:email, '').to_s

    customer_type_id = account.fetch(:customer_type_id)
    if customer_type_id
      customer_type_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: customer_type_id, integration_syncable_type: 'Spree::CustomerType')
      xml.CustomerTypeRef do
        xml.ListID     customer_type_match.try(:sync_id)
      end
    end

    payment_term_id = account.fetch(:payment_term_id)
    if payment_term_id
      payment_term_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: payment_term_id, integration_syncable_type: 'Spree::PaymentTerm')
      xml.TermsRef do
        xml.ListID     payment_term_match.try(:sync_id)
      end
    end

    rep_id = account.fetch(:rep_id)
    if rep_id
      rep_match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: rep_id, integration_syncable_type: 'Spree::Rep', sync_type: 'SalesRep')
      xml.SalesRepRef do
        xml.ListID     rep_match.try(:sync_id)
      end
    end

    xml.AccountNumber  account.fetch(:number, '')
    unless account.fetch(:credit_limit, nil).blank?
      xml.CreditLimit    qbd_amt_type(account.fetch(:credit_limit, nil))
    end
    # Return XML
    xml
  end

  def qbd_account_find_by_name(full_name)
    account = self.integration_item.company.customer_accounts.where(
      fully_qualified_name: full_name
    ).first

    account
  end

  def qbd_find_account_by_id_or_name(hash, base_key)
    qbd_account_id = hash.fetch(base_key, {}).fetch('ListID', nil)
    qbd_account_full_name = hash.fetch(base_key, {}).fetch('FullName', nil)
    return nil unless qbd_account_id.present? || qbd_account_full_name.present?

    account_match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::Account',
      sync_id: qbd_account_id
    ).first

    account = self.company.customer_accounts.where(id: account_match.try(:integration_syncable_id)).first
    account ||= self.company.customer_accounts.where(fully_qualified_name: qbd_account_full_name).first

    if account.nil?
      sync_step = self.integration_steps.find_or_initialize_by(
        integrationable_type: 'Spree::Account',
        sync_type: 'Customer',
        sync_id: qbd_account_id
      )
      sync_step.parent_id ||= self.current_step.try(:id)
      sync_step.details = qbd_account_pull_step_hash.merge(
        {'qbxml_query_by' => 'ListID', 'sync_id' => qbd_account_id, 'sync_full_name' => qbd_account_full_name}
      )

      sync_step.save
    end

    account
  end

  def qbd_account_create(qbd_hash, qbxml_class)
    Sidekiq::Client.push(
      'class' => PullObjectWorker,
      'queue' => 'integrations',
      'args' => [
        self.integration_item.id,
        'Spree::Account',
        qbxml_class,
        qbd_hash.fetch('ListID'),
        qbd_hash.fetch('FullName')
      ]
    )

    return
  end

  def qbd_customer_xml_to_account(response, account_hash)
    account = self.company.customer_accounts.find_by_id(account_hash.fetch(:account, {}).fetch(:id, nil))
    xpath_base = '//QBXML/QBXMLMsgsRs/CustomerQueryRs/CustomerRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("CustomerRet", {})
    qbd_customer_hash_to_account(qbd_hash, account)

    # Need to return a hash because calling method is expecting hash of attributes to update
    return {}
  end

  def qbd_all_associated_matched_customer?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/CustomerQueryRs/CustomerRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("CustomerRet", {})

    qbd_customer_find_or_assign_associated_opts(qbd_hash)

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_customer_find_or_assign_associated_opts(qbd_hash, account = nil)
    parent_fully_qualifed_name = qbd_hash.fetch('ParentRef', {}).fetch('FullName', '')
    if parent_fully_qualifed_name.present?
      parent_id = self.company.customer_accounts.where(
        fully_qualified_name: parent_fully_qualifed_name
      ).first.try(:id)

      raise "Unable to find account #{parent_fully_qualifed_name}" unless parent_id
    else
      parent_id = nil
    end

    if self.integration_item.qbd_sync_customer_class?
      txn_class = qbd_find_transaction_class_by_id_or_name(qbd_hash, 'ClassRef')
    end
    rep = qbd_find_rep_by_id_or_name(qbd_hash, 'SalesRepRef')
    cust_type = qbd_find_customer_type_by_id_or_name(qbd_hash, 'CustomerTypeRef')
    payment_term = qbd_find_payment_term_by_id_or_name(qbd_hash, 'TermsRef')
    balance = qbd_hash.fetch('Balance', nil)
    if account
      account.parent_id = parent_id
      account.rep_id = rep.try(:id)
      account.customer_type_id = cust_type.try(:id)
      account.payment_terms_id = payment_term.try(:id)
      account.external_balance = balance unless balance.nil?

      if self.integration_item.qbd_sync_customer_class?
        account.default_txn_class_id = txn_class.try(:id)
      end
    end
  end

  def qbd_customer_hash_to_account(qbd_hash, account = nil)
    if account.nil?
      customer_company = self.integration_item.company.customers.where(
        name: qbd_hash.fetch('FullName', '').split(':').first
      ).first
      customer_company ||= Spree::Company.new(name: qbd_hash.fetch('FullName', '').split(':').first)
      customer_company.time_zone ||= self.company.try(:time_zone)
      customer_company.save!
      account = Spree::Account.new(
        customer_id: customer_company.id,
        vendor_id: self.company.id
      )
    end
    bill_addr_hash = qbd_hash.fetch('BillAddress', {})
    ship_addr_hash = qbd_hash.fetch('ShipAddress', {})
    bill_address = qbd_address_hash_to_address(bill_addr_hash, account, 'billing', account.bill_address)  # need to update for multiple ship addresses?
    ship_address = qbd_address_hash_to_address(ship_addr_hash, account, 'shipping', account.default_ship_address)   # need to update for multiple ship addresses?
    account.email = qbd_hash.fetch('Email', '')
    account.name = qbd_hash.fetch('Name', '') if qbd_hash.fetch('Name', '').present?
    account.number = qbd_hash.fetch('AccountNumber', '') if qbd_hash.has_key?('AccountNumber')
    account.credit_limit = qbd_hash.fetch('CreditLimit', nil)
    bill_address.account = account
    ship_address.account = account
    qbd_customer_find_or_assign_associated_opts(qbd_hash, account)
    if account.id.nil?
      account.billing_addresses << bill_address
      account.shipping_addresses << ship_address
      account.bill_address = bill_address
      account.default_ship_address = ship_address
      # qbd_find_or_build_match(account, "Spree::Account", qbd_hash.fetch('ListID'), 'Customer', qbd_hash.fetch('EditSequence', nil))
    else
      # qbd_create_or_update_match(account, "Spree::Account", qbd_hash.fetch('ListID'), 'Customer', qbd_hash.fetch('EditSequence', nil))
    end

    account.save!
    qbd_create_or_update_match(account,
                                'Spree::Account',
                                qbd_hash.fetch('ListID'),
                                'Customer',
                                qbd_hash.fetch('TimeCreated'),
                                qbd_hash.fetch('TimeModified'),
                                qbd_hash.fetch('EditSequence', nil))

    if integrationable_id.nil? && sync_id.present? && integrationable_type == 'Spree::Account'
      account_match = account.integration_sync_matches.where(
        integration_item_id: self.integration_item_id,
        sync_id: sync_id
      ).first
      self.update_columns(integrationable_id: account.id) if account_match.present?
    end
  end

  def qbd_address_hash_to_address(qbd_hash, account, address_type, address = nil)
    address ||= Spree::Address.new(account: account, addr_type: address_type)
    return address if qbd_hash.empty?
    address.city = qbd_hash.fetch('City', '')
    address.zipcode = qbd_hash.fetch('PostalCode', '')

    country_name = qbd_hash.fetch('Country', '')
    country = nil
    if country_name.present?
      country = Spree::Country.where('name ilike ?', country_name).first
      country ||= Spree::Country.where('iso_name ilike ?', country_name).first
      country ||= Spree::Country.where('iso3 ilike ?', country_name).first
      country ||= Spree::Country.where('iso ilike ?', country_name).first
    end

    state_name = qbd_hash.fetch('State', '')
    state = nil
    if state_name.present?
      if country.present?
        state = country.states.where('name ilike ?', state_name).first
        state ||= country.states.where('abbr ilike ?', state_name).first
      else
        default_country = account.default_country
        state = default_country.states.where('name ilike ?', state_name).first
        state ||= default_country.states.where('abbr ilike ?', state_name).first
        state ||= Spree::State.where('name ilike ?', state_name).first
        state ||= Spree::State.where('abbr ilike ?', state_name).first
        country = state.try(:country)
      end
    end

    address.country_id = country.try(:id)
    address.state_id = state.try(:id)
    last_line_number = 0
    addr_attrs = [address.city, state_name, address.zipcode].keep_if(&:present?)
    5.times do |n|
      addr_line = qbd_hash.fetch("Addr#{n + 1}", '')
      next if addr_line.blank?
      last_line_number = n
      if addr_attrs.any? {|addr_attr| addr_line.include?(addr_attr) }
        break
      else
        last_line_number += 1
      end
    end
    case last_line_number
    when 0
      address.company = ''
      address.address1 = ''
      address.address2 = ''
    when 1
      address.company = ''
      address.address1 = qbd_hash.fetch("Addr1", '')
      address.address2 = ''
    when 2
      address.company = ''
      address.address1 = qbd_hash.fetch("Addr1", '')
      address.address2 = qbd_hash.fetch("Addr2", '')
    else
      address.company = qbd_hash.fetch("Addr1", '')
      address.address1 = qbd_hash.fetch("Addr2", '')
      address.address2 = qbd_hash.fetch("Addr3", '')
    end

    address.save!

    address
  end

  def qbd_account_query_step_hash(account_id = nil)
    { step_type: :query, object_id: account_id, object_class: 'Spree::Account', qbxml_class: 'Customer', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  def qbd_account_create_step_hash(account_id = nil)
    { step_type: :create, object_id: account_id, object_class: 'Spree::Account', qbxml_class: 'Customer', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  def qbd_account_pull_step_hash(account_id = nil)
    { step_type: :pull, object_id: account_id, object_class: 'Spree::Account', qbxml_class: 'Customer', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end
  def qbd_account_push_step_hash(account_id = nil)
    { step_type: :push, object_id: account_id, object_class: 'Spree::Account', qbxml_class: 'Customer', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
  end

  def qbd_account_next_step_hash(account_id = nil)
    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: account_id, integration_syncable_type: 'Spree::Account')
    if match.sync_id.nil?
      next_step = qbd_account_query_step_hash(account_id)
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      next_step = qbd_account_create_step_hash(account_id)
    else
      if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = qbd_account_push_step_hash(account_id)
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        next_step = qbd_account_pull_step_hash(account_id)
      else
        next_step = qbd_account_query_step_hash(account_id).merge({next_step: is_parent ? :continue : :skip})
      end
    end

    next_step
  end

end
