class InventoryHistoryWorker
  include Sidekiq::Worker

  def perform(stock_movement_id, available_count, opts = {})
    sm = Spree::StockMovement.find(stock_movement_id)
    InventoryHistory::Service.new(sm, available_count, opts).save
  rescue ActiveRecord::RecordNotFound
    true # moving on if action has been removed from DB
  end

end
