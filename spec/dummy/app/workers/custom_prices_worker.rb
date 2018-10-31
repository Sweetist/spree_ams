class CustomPricesWorker
  include Sidekiq::Worker

  def perform(avv_id)
    avv = Spree::AccountViewableVariant.find_by_id(avv_id)
    return unless avv.present?
    
    if avv.account.nil?
      avv.delete
    elsif avv.variant.nil?
      avv.delete
    else
      avv.find_eligible_promotions
      avv.cache_price(avv.eligible_promotions.unadvertised)
    end
  end

end
