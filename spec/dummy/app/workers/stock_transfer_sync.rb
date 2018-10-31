class StockTransferSync
  include Sidekiq::Worker

  def perform(stock_transfer_id, vendor_id)
    stock_transfer = Spree::StockTransfer.find(stock_transfer_id)

    Spree::Integration.available_vendors_integrations(stock_transfer.company).each do |integration|
      integration.fetch(:integrations, []).each do |integration_item|
        next unless integration_item.should_sync_inventory(stock_transfer)
        next if Spree::IntegrationAction.where(integrationable: stock_transfer, integration_item: integration_item, status: 0).present?

        create_action(stock_transfer, integration_item)
      end
    end
  rescue ActiveRecord::RecordNotFound
    true # moving on if stock transfer has been removed from DB
  end

  def create_action(stock_transfer, integration_item)
    action = Spree::IntegrationAction.create(integrationable: stock_transfer, integration_item: integration_item)
    action.push_to_sidekiq
  end

end
