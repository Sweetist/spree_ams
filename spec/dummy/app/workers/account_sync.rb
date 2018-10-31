class AccountSync
  include Sidekiq::Worker

  def perform(account_id)
    account = Spree::Account.find(account_id)

    Spree::IntegrationItem.where(account_sync: true, vendor_id: [account.vendor_id, account.customer_id]).each do |integration_item|
      next unless integration_item.account_sync?
      next if integration_item.vendor_id == account.vendor_id && !integration_item.should_sync_customer(account)
      next if integration_item.vendor_id == account.customer_id && !integration_item.should_sync_vendor(account)
      next if Spree::IntegrationAction.where(integrationable: account, integration_item: integration_item, status: 0).present?
      if account.can_sync?(integration_item)
        create_action(account, integration_item)
      else
        account.integration_sync_matches.find_by(integration_item: integration_item).try(:update_columns, {no_sync: false})
      end
    end
  rescue ActiveRecord::RecordNotFound
    true # moving on if customer has been removed from DB
  end

  def create_action(account, integration_item)
    action = Spree::IntegrationAction.create(integrationable: account, integration_item: integration_item)
    action.push_to_sidekiq
  end

end
