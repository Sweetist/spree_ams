class OrderSync
  include Sidekiq::Worker

  def perform(order_id)
    order = Spree::Order.find(order_id)
    return if order.state == 'cart' #can happen when state is rolled back after failed required payment
    order.sync_payments if order.state == 'approved'
    account = order.account
    Spree::IntegrationItem.where(order_sync: true, vendor_id: [account.customer_id, account.vendor_id]).each do |integration_item|
      next if integration_item.vendor_id == account.vendor_id && !integration_item.should_sync_order(order)
      next if integration_item.vendor_id == account.customer_id && !integration_item.should_sync_purchase_order(order.channel)
      next if order.state == 'complete' && integration_item.vendor_id == order.vendor_id
      next if Spree::IntegrationAction.where(integrationable: order, integration_item: integration_item, status: 0).present?

      create_action(order, integration_item)

    end
  rescue ActiveRecord::RecordNotFound
    true # moving on if order has been removed from DB
  end

  def create_action(order, integration_item)
    action = Spree::IntegrationAction.create(integrationable: order, integration_item: integration_item)
    action.push_to_sidekiq(5.seconds)
  end

end
