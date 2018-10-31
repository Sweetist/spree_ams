class PriceListAvvWorker
  include Sidekiq::Worker

  def perform(price_list_id, vendor_id)
    vendor = Spree::Company.find(vendor_id)
    price_list = vendor.price_lists.find_by_id(price_list_id)

    if price_list.try(:active)
      @applicable_avvs = vendor.account_viewable_variants
        .where(
          "recalculating != ? AND ((variant_id IN (?) AND account_id IN (?)) OR price_list_id = ?)",
          Spree::AccountViewableVariant::RecalculatingStatus['enqueued'],
          price_list.price_list_variants.pluck(:variant_id),
          price_list.account_ids,
          price_list_id
        )
    else
      @applicable_avvs = vendor.account_viewable_variants
        .where(
          "recalculating != ? AND price_list_id = ?",
          Spree::AccountViewableVariant::RecalculatingStatus['enqueued'],
          price_list_id
        )
    end

    if vendor.set_visibility_by_price_list
      if price_list.try(:active) || price_list.nil?
        avv_account_ids = @applicable_avvs.pluck(:account_id).uniq
      else
        avv_account_ids = price_list.account_ids
      end
      vendor.customer_accounts.joins(price_lists: :price_list_variants)
                              .where(id: avv_account_ids).find_each do |account|
        account.set_catalog_visibility_from_price_lists
      end
    end

    @applicable_avvs.update_all(recalculating: Spree::AccountViewableVariant::RecalculatingStatus['backlog'])

    @applicable_avvs.find_in_batches do |avvs|
      Sidekiq::Client.push('class' => CreateAvvJobsWorker, 'queue' => 'default', 'args' => [avvs.map(&:id)])
    end

  end

end
