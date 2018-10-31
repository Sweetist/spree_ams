class PaymentSync
  include Sidekiq::Worker

  def perform(payment_id)
    payment = Spree::Payment.find_by_id(payment_id)
    return if payment.nil?
    return if payment.account_payment.present?
    order = payment.order
    # Not syncing payments for order that is not yet synced
    return if States[order.try(:state)].to_i.between?(States['cart'], States['complete'])

    Spree::Integration.available_vendors_integrations(order.vendor).each do |integration|
      integration.fetch(:integrations, []).each do |integration_item|
        next unless integration_item.should_sync_payment(payment)
        next if Spree::IntegrationAction.where(integrationable: payment, integration_item: integration_item, status: 0).present?

        create_action(payment, integration_item)
      end
    end
  rescue ActiveRecord::RecordNotFound
    true # moving on if payment has been removed from DB
  end

  def create_action(payment, integration_item)
    action = Spree::IntegrationAction.create(integrationable: payment, integration_item: integration_item)
    action.push_to_sidekiq
  end

end
