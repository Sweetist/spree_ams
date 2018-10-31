module Spree::QbdIntegration::Action::ChartAccount

  def qbd_chart_account_step(chart_account_id, parent_step_id = nil)
    chart_account = Spree::ChartAccount.find(chart_account_id)
    account_hash = chart_account.to_integration(
      self.integration_item.integrationable_options_for(chart_account)
    )

    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: chart_account_id,
      integration_syncable_type: 'Spree::ChartAccount'
    )

    if match.sync_id.nil?
      next_step = qbd_chart_account_query_step_hash(chart_account_id)
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      next_step = qbd_chart_account_create_step_hash(chart_account_id)
    else
      if match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'quickbooks'
        next_step = qbd_chart_account_push_step_hash(chart_account_id)
      elsif match.sync_id.present? && self.integration_item.qbd_overwrite_conflicts_in == 'sweet'
        next_step = qbd_chart_account_pull_step_hash(chart_account_id)
      else
        next_step = qbd_chart_account_query_step_hash(chart_account_id).merge({next_step: :skip})
      end
    end

    if account_hash.fetch(:parent_id)
      parent_match = self.integration_item.integration_sync_matches.find_or_create_by(
        integration_syncable_id: account_hash.fetch(:parent_id),
        integration_syncable_type: 'Spree::ChartAccount'
      )
      if parent_match.synced_at.nil? || parent_match.synced_at < Time.current - 10.minute
        child_account_step = qbd_create_step(next_step)
        parent_account_step = qbd_create_step(
          self.qbd_chart_account_step(account_hash.fetch(:parent_id), child_account_step.try(:id))
        )
        next_step = parent_account_step.details
      end
    end

    next_step
  end

  def qbd_chart_account_to_account_xml(xml, account_hash, match = nil)
    if match
      xml.ListID       match.try(:sync_id)
      xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Name          account_hash.fetch(:name)
    if account_hash.fetch(:parent_id).present?
      parent_match = self.integration_item.integration_sync_matches.find_by(
        integration_syncable_type: 'Spree::ChartAccount',
        integration_syncable_id: account_hash.fetch(:parent_id)
      )
      xml.ParentRef do
        xml.ListID  parent_match.try(:sync_id)
      end
    end
    xml.AccountType   qbd_account_type_to_qbd(account_hash.fetch(:account_type))
  end

  def qbd_all_associated_matched_account?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/AccountQueryRs/AccountRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("AccountRet", {})

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_account_xml_to_chart_account(response, chart_account_hash)
    chart_account = self.company.chart_accounts.find_by_id(chart_account_hash.fetch(:id, nil))
    xpath_base = '//QBXML/QBXMLMsgsRs/AccountQueryRs/AccountRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("AccountRet", {})
    qbd_account_hash_to_chart_account(qbd_hash, chart_account)
    # {
    #   name: response.xpath("#{xpath_base}/Name").try(:children).try(:text)
    # }.delete_if { |k, v| v.blank? }

    return {}
  end

  def  qbd_account_type_to_qbd(account_type)
    # ["Income Account", "Cost of Goods Sold Account", "Asset Account", "Expense Account", "Shipping Account", "Discount Account"]
    case account_type.downcase
    when "income account"
      "Income"
    when "cost of goods sold account"
      "CostOfGoodsSold"
    when "asset account"
      "OtherCurrentAsset"
    when "expense account"
      "Expense"
    end

  end

  def qbd_find_chart_account_by_id_or_name(hash, base_key)
    qbd_acc_id = hash.fetch(base_key,{}).fetch('ListID', nil)
    qbd_acc_full_name = hash.fetch(base_key,{}).fetch('FullName', nil)
    acc_match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::ChartAccount',
      sync_id: qbd_acc_id
    ).first
    if acc_match.try(:integration_syncable_id)
      acc = self.integration_item.company.chart_accounts.where(id: acc_match.integration_syncable_id).first
    end
    acc ||= self.integration_item.company.chart_accounts.where(
      fully_qualified_name: qbd_acc_full_name
    ).first

    if acc.nil?
      sync_step = self.integration_steps.find_or_initialize_by(
        integrationable_type: 'Spree::ChartAccount',
        sync_type: 'Account',
        sync_id: qbd_acc_id
      )
      sync_step.parent_id ||= self.current_step.try(:id)
      sync_step.details = qbd_chart_account_pull_step_hash.merge(
        {'qbxml_query_by' => 'ListID', 'sync_id' => qbd_acc_id, 'sync_full_name' => qbd_acc_full_name}
      )

      sync_step.save
    end

    acc
  end

  def qbd_account_hash_to_chart_account(qbd_hash, account = nil)
    full_name = qbd_hash.fetch('FullName', nil)
    account ||= self.company.chart_accounts.where(
      fully_qualified_name: full_name
    ).first

    if account.present?
      cat_id = qbd_chart_account_category_from_qbd(
        qbd_hash.fetch('AccountType', nil),
        qbd_hash.fetch('SpecialAccountType', nil)
      ).try(:id)
      account.chart_account_category_id = cat_id unless cat_id.nil?
      account.save

      return account
    end

    parent_full_name = qbd_hash.fetch('ParentRef', {}).fetch('FullName', nil)
    if parent_full_name.present?
      parent_account = self.company.chart_accounts.where(
        fully_qualified_name: parent_full_name
      ).first
      if parent_account.present?
        #Create account
        account = qbd_create_chart_account_from_account_hash(qbd_hash)
      else
        #Create parent step
        parent_sync_id = qbd_hash.fetch('ParentRef', {}).fetch('ListID', nil)
        sync_step = self.integration_steps.find_or_initialize_by(
          integrationable_type: 'Spree::ChartAccount',
          sync_type: 'Account',
          sync_id: parent_sync_id
        )
        sync_step.master = self.integration_item.qbd_create_related_objects ? 'quickbooks' : 'none'
        sync_step.parent_id = self.current_step.try(:id)
        sync_step.details = qbd_chart_account_pull_step_hash.merge(
          {'qbxml_query_by' => 'ListID','sync_id' => parent_sync_id, 'sync_full_name' => parent_full_name}
        )
        sync_step.save!
      end
    else
      #Create account
      account = qbd_create_chart_account_from_account_hash(qbd_hash)
    end

    qbd_create_or_update_match(account,
                              'Spree::ChartAccount',
                              qbd_hash.fetch('ListID'),
                              'Account',
                              qbd_hash.fetch('TimeCreated'),
                              qbd_hash.fetch('TimeModified'),
                              qbd_hash.fetch('EditSequence', nil))

    account
  end

  def qbd_create_chart_account_from_account_hash(qbd_hash)
    full_name = qbd_hash.fetch('FullName', nil)
    parent_full_name = qbd_hash.fetch('ParentRef', {}).fetch('FullName', nil)

    account = self.company.chart_accounts.new(name: qbd_hash.fetch('Name', nil))
    if parent_full_name.present?
      parent_account = self.company.chart_accounts.where(
        fully_qualified_name: parent_full_name
      ).first
      account.parent_id = parent_account.try(:id)
      account.chart_account_category_id = parent_account.try(:chart_account_category_id)
    else
      account.chart_account_category_id = qbd_chart_account_category_from_qbd(
        qbd_hash.fetch('AccountType', nil),
        qbd_hash.fetch('SpecialAccountType', nil)
      ).try(:id)
    end

    account.save!
  end

  def qbd_chart_account_category_from_qbd(account_type, special_account_type = nil)

    category_name = case account_type.to_s
    when 'CostOfGoodsSold'
      'Cost of Goods Sold Account'
    when 'Income', 'OtherIncome'
      'Income Account'
    when 'Expense', 'OtherExpense'
      'Expense Account'
    when 'Fixed Asset', 'OtherCurrentAsset', 'OtherAsset'
      'Asset Account'
    else
      # other QBD Accounts not currently supported
      # AccountsPayable, AccountsReceivable, Bank, CreditCard, Equity, LongTermLiability, NonPosting, OtherCurrentLiability
      ''
    end

    Spree::ChartAccountCategory.find_by_name(category_name)
  end

  def qbd_chart_account_query_step_hash(chart_account_id = nil)
    { step_type: :query, object_id: chart_account_id, object_class: 'Spree::ChartAccount', qbxml_class: 'Account', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}.as_json
  end

  def qbd_chart_account_pull_step_hash(chart_account_id = nil)
    { step_type: :pull, object_id: chart_account_id, object_class: 'Spree::ChartAccount', qbxml_class: 'Account', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}.as_json
  end

  def qbd_chart_account_push_step_hash(chart_account_id = nil)
    { step_type: :push, object_id: chart_account_id, object_class: 'Spree::ChartAccount', qbxml_class: 'Account', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}.as_json
  end

  def qbd_chart_account_create_step_hash(chart_account_id = nil)
    { step_type: :create, object_id: chart_account_id, object_class: 'Spree::ChartAccount', qbxml_class: 'Account', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}.as_json
  end

end
