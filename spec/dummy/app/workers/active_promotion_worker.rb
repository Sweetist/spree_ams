class ActivePromotionWorker
  include Sidekiq::Worker

  def perform
    Spree::Promotion.where('starts_at BETWEEN ? AND ?', Time.current.beginning_of_day - 1.day, Time.current).each do |promotion|
      Sidekiq::Client.push('class' => CacheDiscountedPricesWorker, 'queue' => 'products', 'args' => [promotion.vendor_id, promotion.id, 'start'])
    end
    Spree::Promotion.where('expires_at BETWEEN ? AND ?', Time.current.beginning_of_day - 1.day, Time.current).each do |promotion|
      Sidekiq::Client.push('class' => CacheDiscountedPricesWorker, 'queue' => 'products', 'args' => [promotion.vendor_id, promotion.id, 'expire'])
    end
  end

end
