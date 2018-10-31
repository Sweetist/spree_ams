require 'rufus-scheduler'

scheduler = Rufus::Scheduler.new

scheduler.interval '1m' do
  Integrations::ActionHelpers.mark_failed_jobs
end
