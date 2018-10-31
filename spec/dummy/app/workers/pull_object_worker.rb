class PullObjectWorker
  include Sidekiq::Worker
  def perform(integration_id, object_class, sync_type, sync_id, full_name)
    integration_item = Spree::IntegrationItem.find(integration_id)
    create_integration_action(integration_item, object_class, sync_type, sync_id, full_name)
  rescue ActiveRecord::RecordNotFound
    true # moving on if integration has been removed
  end

  def create_integration_action(integration_item, object_class, sync_type, sync_id, full_name)
    if Spree::IntegrationAction.where(
      integrationable_id: nil,
      integration_item: integration_item,
      integrationable_type: object_class,
      sync_type: sync_type,
      sync_id: sync_id,
      status: [-1, 0]).empty?
      action = Spree::IntegrationAction.create(
        integrationable_id: nil,
        integration_item: integration_item,
        integrationable_type: object_class,
        sync_type: sync_type,
        sync_fully_qualified_name: full_name || sync_id,
        sync_id: sync_id
      )
      Sidekiq::Client.push(
        'class' => IntegrationWorker,
        'queue' => integration_item.queue_name,
        'args' => [action.id]
      ) # unless (integration_item.method("#{integration_item.integration_key}_group_sync").call rescue true)
    else
      action = Spree::IntegrationAction.where(
        integrationable_id: nil,
        integration_item: integration_item,
        integrationable_type: object_class,
        sync_type: sync_type,
        sync_id: sync_id,
        status: -1
      ).last
      if action
        action.update_columns(
          updated_at: Time.current,
          sync_fully_qualified_name: full_name || sync_id,
          enqueued_at: Time.current,
          processed_at: nil,
          status: 0
        )
        Sidekiq::Client.push('class' => IntegrationWorker, 'queue' => integration_item.queue_name, 'args' => [action.id])
      end
    end
  end
end
