#lib/tasks/scheduler.rake

namespace :scheduler do

  desc "Launch Background scheduler for Standing Orders"
  task launch: :environment do
    Sidekiq::Client.push('class' => ScheduleWorker, 'queue' => 'default', 'args' => [])
    Sidekiq::Client.push('class' => ActivePromotionWorker, 'queue' => 'products', 'args' => [])
  end

  desc "Automated polling of integrations"
  task poll_integrations: :environment do
    Sidekiq::Client.push('class' => IntegrationPollingWorker, 'queue' => 'default', 'args' => [])
  end
end
