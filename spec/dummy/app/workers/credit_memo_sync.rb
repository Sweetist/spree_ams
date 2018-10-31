class CreditMemoSync
  include Sidekiq::Worker

  def perform(credit_memo_id)
    credit_memo = Spree::CreditMemo.find(credit_memo_id)
    Spree::IntegrationItem.where(vendor_id: credit_memo.vendor_id).each do |integration_item|
      next unless integration_item.should_sync_credit_memo(credit_memo)
      next if Spree::IntegrationAction.where(integrationable: credit_memo, integration_item: integration_item, status: 0).present?

      create_action(credit_memo, integration_item)
    end
  rescue ActiveRecord::RecordNotFound
    true # moving on if credit_memo has been removed from DB
  end

  def create_action(credit_memo, integration_item)
    action = Spree::IntegrationAction.create(integrationable: credit_memo, integration_item: integration_item)
    action.push_to_sidekiq
  end

end
