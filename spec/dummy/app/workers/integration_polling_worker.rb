class IntegrationPollingWorker
  include Sidekiq::Worker

  def perform
    Spree::IntegrationItem.where(integration_key: 'qbd').find_each do |ii|
      ii.poll
    end
  end
end
