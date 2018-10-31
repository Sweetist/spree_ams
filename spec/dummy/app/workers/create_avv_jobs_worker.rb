class CreateAvvJobsWorker
  include Sidekiq::Worker

  def perform(avv_ids)
    Spree::AccountViewableVariant.where(id: avv_ids).find_each do |avv|
      if avv.recalculating != Spree::AccountViewableVariant::RecalculatingStatus['enqueued']
        avv.update_columns(recalculating: Spree::AccountViewableVariant::RecalculatingStatus['enqueued'])
        Sidekiq::Client.push('class' => CustomPricesWorker, 'queue' => 'products', 'args' => [avv.id])
      end
    end
  end

end
