module Integrations
  class ActionHelpers
    def self.mark_failed_jobs
      old_level = ActiveRecord::Base.logger.level
      ActiveRecord::Base.logger.level = 1

      Spree::IntegrationAction
        .joins(:integration_item)
        .where('spree_integration_items.should_timeout = ?', true)
        .where(status: 1)
        .where('last_response_time <= :minutes_ago',
               minutes_ago: Time.current - 2.minutes)
        .update_all(status: -1, execution_log: 'Call timed out')

      ActiveRecord::Base.logger.level = old_level
    end
  end
end
