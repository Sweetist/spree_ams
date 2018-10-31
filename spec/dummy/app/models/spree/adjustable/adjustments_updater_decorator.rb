Spree::Adjustable::AdjustmentsUpdater.class_eval do

   def best_promo_adjustment
     @best_promo_adjustment ||= begin
       adjustment = adjustments.competing_promos.eligible.reorder("amount ASC, created_at DESC, id DESC").first
       adjustment && adjustment.source && adjustment.source.promotion.advertise ? adjustment : nil
     end
   end

end
