class ProductSync
  include Sidekiq::Worker

  def perform(product_id)
    product = Spree::Product.find_by(id: product_id)
    return unless product
    integrations = product.try(:vendor).try(:integration_items) || []
    integrations.each do |integration_item|
      next unless integration_item.should_sync_product
      next if Spree::IntegrationAction.where(integrationable: product, integration_item: integration_item, status: 0).present?

      create_action(product, integration_item)
    end
  end

  def create_action(product, integration_item)
    action = Spree::IntegrationAction.create(integrationable: product, integration_item: integration_item)
    action.push_to_sidekiq
  end
  
end
