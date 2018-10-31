class AccountCreateAvvWorker
  include Sidekiq::Worker

  def perform(account_id, vendor_id)
    avv_ids = []
    Spree::Variant.joins(:product).where('spree_products.vendor_id = ?', vendor_id).each do |variant|
      make_visible = variant.should_make_visible?
      avv = variant.account_viewable_variants.find_by(account_id: account_id)
      avv ||= variant.account_viewable_variants.new(
        account_id: account_id,
        recalculating: Spree::AccountViewableVariant::RecalculatingStatus['new']
      )
      avv.visible ||= make_visible
      avv.save
      avv_ids << avv.id unless avv.recalculating == Spree::AccountViewableVariant::RecalculatingStatus['enqueued']
    end
    Sidekiq::Client.push('class' => CreateAvvJobsWorker, 'queue' => 'default', 'args' => [avv_ids])
  end

end
