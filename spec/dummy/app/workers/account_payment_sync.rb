class AccountPaymentSync
  include Sidekiq::Worker

  def perform(account_payment_id)
    account_payment = Spree::AccountPayment.find(account_payment_id)
    # Not syncing account_payments for order that is not yet synced
    orders = account_payment.orders
    if orders.count == 1
      order = orders.first
      return if States[order.try(:state)].to_i.between?(States['cart'], States['complete'])
    end
    Spree::Integration.available_vendors_integrations(account_payment.vendor).each do |integration|
      integration.fetch(:integrations, []).each do |integration_item|
        next unless integration_item.should_sync_account_payment(account_payment)
        next if Spree::IntegrationAction.where(integrationable: account_payment, integration_item: integration_item, status: 0).present?

        create_action(account_payment, integration_item)
      end
    end
  rescue ActiveRecord::RecordNotFound
    true # moving on if account_payment has been removed from DB
  end

  def create_action(account_payment, integration_item)
    action = Spree::IntegrationAction.create(integrationable: account_payment, integration_item: integration_item)
    action.push_to_sidekiq
  end

end
