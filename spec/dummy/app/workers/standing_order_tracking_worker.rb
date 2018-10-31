class StandingOrderTrackingWorker
  include Sidekiq::Worker

  def perform(tracker_id)
    tracker = Spree::StandingOrderTracker.find(tracker_id)
    tracker.stop_tracking!
  rescue ActiveRecord::RecordNotFound
    true # moving on if tracker has been removed from DB
  end
end
