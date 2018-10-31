class SweetistSyncWorker
  include Sidekiq::Worker
  include Spree::Syncable

    def perform(syncable_class, integration_item_id, syncable_id = nil, integration_sync_id = nil)
      # syncable refers to the object in Sweet
      # integration_sync_id refers to the object in Sweetist

      # Default values
      url = ''
      method = :get
      payload = {}

      integration_item = Spree::IntegrationItem.find_by_id(integration_item_id)

      case syncable_class
      when 'Spree::IntegrationItem'
        url = "#{ENV['SWEETIST_INTEGRATION_URL']}/api/bakeries/#{integration_item.sweetist_bakery_id}"
        url << "?on=#{integration_item.sweetist_integration_state}&token=#{ENV['SWEETIST_API_KEY']}"
        payload = integration_item.sweetist_bakery_hash
        method = :patch
      when 'Spree::Order'
        url = "#{ENV['SWEETIST_INTEGRATION_URL']}/api/orders/#{integration_sync_id}?token=#{ENV['SWEETIST_API_KEY']}"
        method = :patch
        payload = build_sweetist_order
      end
      send_request(url, method, payload)
    end


  end
