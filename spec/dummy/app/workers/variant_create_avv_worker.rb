class VariantCreateAvvWorker
  include Sidekiq::Worker

  def perform(variant_id, vendor_id)
    avv_ids = []
    variant = Spree::Variant.find_by_id(variant_id)
    return unless variant
    make_visible = variant.should_make_visible?
    Spree::Account.where(vendor_id: vendor_id).each do |account|
        avv = account.account_viewable_variants.find_by(variant_id: variant.id)
        if avv
          unless avv.recalculating == Spree::AccountViewableVariant::RecalculatingStatus['enqueued']
            avv.recalculating = Spree::AccountViewableVariant::RecalculatingStatus['backlog']
          end
          avv.visible ||= make_visible
          avv.save
        else
          avv = account.account_viewable_variants.new(
            variant_id: variant.id,
            recalculating: Spree::AccountViewableVariant::RecalculatingStatus['new']
          )
          avv.visible ||= make_visible
          avv.save
        end
        avv_ids << avv.id unless avv.recalculating == Spree::AccountViewableVariant::RecalculatingStatus['enqueued']
      end
    Sidekiq::Client.push('class' => CreateAvvJobsWorker, 'queue' => 'default', 'args' => [avv_ids])
  end

end
