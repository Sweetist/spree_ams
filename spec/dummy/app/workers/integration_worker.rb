class IntegrationWorker
  include Sidekiq::Worker

  def perform(integration_action_id)
    action = Spree::IntegrationAction.find(integration_action_id)

    action.trigger!
  rescue ActiveRecord::RecordNotFound
    true # moving on if action has been removed from DB
  end
end
