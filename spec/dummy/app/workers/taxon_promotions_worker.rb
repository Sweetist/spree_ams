class TaxonPromotionsWorker
  include Sidekiq::Worker

  def perform(vendor_id, promotion_ids)
    promotion_ids.each do |pid|
      Sidekiq::Client.push('class' => CacheDiscountedPricesWorker, 'queue' => 'critical', 'args' => [vendor_id, pid, 'update'])
    end
  end
end
