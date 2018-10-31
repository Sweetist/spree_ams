class CacheDiscountedPricesWorker
  include Sidekiq::Worker

  def perform(vendor_id, promotion_id, action)
    vendor = Spree::Company.find(vendor_id)
    promotion = vendor.promotions.find_by_id(promotion_id)

    # Set action to 'delete' because only want to remove the promotion from existing products/variants
    # if it is being advertised, ie we are showing the base price with an order adjustment
    action = 'delete' if promotion.try(:advertise)
    case action
    when 'update' || 'start'

      @applicable_avvs = vendor.account_viewable_variants
        .where(
          "recalculating != ? AND((variant_id IN (?) AND account_id IN (?)) OR ? = ANY(promotion_ids))",
          Spree::AccountViewableVariant::RecalculatingStatus['enqueued'],
          promotion.eligible_variant_ids,
          promotion.eligible_account_ids,
          promotion_id.to_s
        )

      @applicable_avvs.update_all(recalculating: Spree::AccountViewableVariant::RecalculatingStatus['backlog'])

      @applicable_avvs.find_in_batches do |avvs|
        Sidekiq::Client.push('class' => CreateAvvJobsWorker, 'queue' => 'default', 'args' => [avvs.map{|avv| avv.id}])
      end

    when 'delete' || 'expire'
      @applicable_avvs = vendor.account_viewable_variants
        .where(
          "recalculating != ? AND ? = ANY(promotion_ids)",
          Spree::AccountViewableVariant::RecalculatingStatus['enqueued'],
          promotion_id.to_s
        )

      @applicable_avvs.update_all(recalculating: Spree::AccountViewableVariant::RecalculatingStatus['backlog'])

      @applicable_avvs.find_in_batches do |avvs|
        Sidekiq::Client.push('class' => CreateAvvJobsWorker, 'queue' => 'default', 'args' => [avvs.map{|avv| avv.id}])
      end
    end
  end
end
