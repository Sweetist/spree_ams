module Spree::QboIntegration::Action::ChartAccount
  # Synchronize Variant

  def qbo_synchronize_chart_account(account_id)
    chart_account = self.company.chart_accounts.find_by_id(account_id)
    account_hash = chart_account.to_integration(
        self.integration_item.integrationable_options_for(chart_account)
      )
    service = self.integration_item.qbo_service('Account')

    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: account_hash.fetch(:self).try(:id),
      integration_syncable_type: 'Spree::ChartAccount')
    if match.sync_id
      qbo_account = service.fetch_by_id(match.sync_id)
      qbo_update_account(qbo_account, account_hash, service)
    else
      qbo_account = service.query("select * from Account where FullyQualifiedName='#{self.qbo_safe_string(account_hash.fetch(:fully_qualified_name))}'").first
      if qbo_account
        # we have a match, save ID
        match.sync_id = qbo_account.id
        match.sync_type = qbo_account.class.to_s
        match.save
        qbo_update_account(qbo_account, account_hash, service)
      elsif self.integration_item.qbo_create_related_objects
        qbo_new_account = qbo_account_to_qbo(
          Quickbooks::Model::Account.new,
          account_hash
        )

        response = service.create(qbo_new_account)
        match.sync_id = response.id
        match.sync_type = response.class.to_s
        match.save
        { status: 10, log: "#{account_hash.fetch(:name_for_integration)} => Pushed." }
      else
        { status: -1, log: "#{account_hash.fetch(:name_for_integration)} => Unable to find Match for #{name}" }

      end
    end

  rescue Exception => e
    { status: -1, log: "#{e.class.to_s} - #{e.message}" }
  end

  def qbo_update_account(qbo_account, account_hash, service)
    qbo_updated_account = qbo_account_to_qbo(qbo_account, account_hash)
    if self.integration_item.qbo_overwrite_conflicts_in == 'quickbooks'
      service.update(qbo_updated_account)
      { status: 10, log: "#{account_hash.fetch(:name_for_integration)} category => Match updated in QBO." }
    elsif self.integration_item.qbo_overwrite_conflicts_in == 'sweet'
      { status: 3, log: "#{account_hash.fetch(:name_for_integration)} category => Not currently supported"}
    else
      { status: 10, log: "#{account_hash.fetch(:name_for_integration)} category => No conflict resolution." }
    end
  end

  def qbo_account_to_qbo(qbo_account, account_hash)
    account_type = account_hash.fetch(:account_type)
    qbo_account.name = account_hash.fetch(:name)
    qbo_account.classification = qbo_account_classification_to_qbo(account_type)
    qbo_account.account_type = qbo_account_type_to_qbo(account_type)
    unless qbo_account.id #only set when creating new
      qbo_account.account_sub_type = qbo_account_sub_type_to_qbo(account_type)
    end

    if account_hash.fetch(:parent_id).present?
      sync_parent = qbo_synchronize_chart_account(account_hash.fetch(:parent_id))
      if sync_parent.fetch(:status)
        parent = self.integration_item.integration_sync_matches.find_by(
          integration_syncable_id: account_hash.fetch(:parent_id),
          integration_syncable_type: 'Spree::ChartAccount'
        )
      else
        return sync_parent
      end
      qbo_account.sub_account = true
      qbo_account.parent_ref = Quickbooks::Model::BaseReference.new(parent.try(:sync_id))
    end

    qbo_account
  end

  def qbo_account_classification_to_qbo(account_type)
    case account_type
    when "Income Account"
      "Revenue"
    when "Cost of Goods Sold Account"
      "Expense"
    when "Asset Account"
      "Asset"
    when "Expense Account"
      "Expense"
    end
  end

  def qbo_account_type_to_qbo(account_type)
    case account_type
    when "Income Account"
      "Income"
    when "Cost of Goods Sold Account"
      "CostOfGoodsSold"
    when "Asset Account"
      "Other Current Asset"
    when "Expense Account"
      "Expense"
    end
  end

  def qbo_account_sub_type_to_qbo(account_type)
    case account_type
    when "Income Account"
      "SalesOfProductIncome"
    when "Cost of Goods Sold Account"
      "SuppliesMaterialsCogs"
    when "Asset Account"
      "Inventory"
    when "Expense Account"
      "SuppliesMaterials"
    end
  end

end
