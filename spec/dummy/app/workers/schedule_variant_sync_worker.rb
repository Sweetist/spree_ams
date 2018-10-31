class ScheduleVariantSyncWorker
  include Sidekiq::Worker

  def perform(integration_item_id, sync_all = false)
    begin
      integration_item = Spree::IntegrationItem.find(integration_item_id)
      vendor_id = integration_item.vendor_id
      if sync_all
        integration_item.vendor.variants_including_master.find_each do |variant|
          Sidekiq::Client.push('class' => VariantSync, 'queue' => 'integrations', 'args' => [variant.id, vendor_id, integration_item_id])
        end
      else
        integration_item.unsynced_variants.find_each do |variant|
          Sidekiq::Client.push('class' => VariantSync, 'queue' => 'integrations', 'args' => [variant.id, vendor_id, integration_item_id])
        end
      end

    rescue ActiveRecord::RecordNotFound
      true # moving on if variant has been removed from DB
    end
  end

end
