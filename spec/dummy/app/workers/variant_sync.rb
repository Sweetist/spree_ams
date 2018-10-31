class VariantSync
  include Sidekiq::Worker

  def perform(variant_id, vendor_id, integration_item_id = nil)
    variant = Spree::Variant.find(variant_id)
    if integration_item_id
      integration_item = Spree::IntegrationItem.find(integration_item_id)
      create_action(variant, integration_item)
    else
      Spree::Integration.available_vendors_integrations(variant.vendor).each do |integration|
        integration.fetch(:integrations, []).each do |integration_item|
          next unless integration_item.should_sync_variant(variant)
          next if Spree::IntegrationAction.where(integrationable: variant, integration_item: integration_item, status: 0).present?
          if variant.can_sync?(integration_item)
            create_action(variant, integration_item)
          else
            variant.integration_sync_matches.find_by(integration_item: integration_item).try(:update_columns, {no_sync: false})
          end
        end
      end
    end
  rescue ActiveRecord::RecordNotFound
    true # moving on if variant has been removed from DB
  end

  def create_action(variant, integration_item)
    action = Spree::IntegrationAction.create(integrationable: variant, integration_item: integration_item)
    action.push_to_sidekiq
  end

end
