namespace :db do

  desc 'Migrate AVPs to AVVs'
  task create_account_viewable_variants: :environment do

    Spree::Company.vendor_companies.each do |vendor|
      next if vendor.name == 'Brooklyn Roasting Company'
      puts "Start Vendor: #{vendor.name}"
      vendor.products.each do |p|
        vendor.customer_accounts.each do |a|

          avp = a.account_viewable_products.where(product_id: p.id).first
          variants_exist = p.has_variants?
          if avp
            p.variants_including_master.each do |v|
              avv = a.account_viewable_variants.find_or_initialize_by(variant_id: v.id)
              if variants_exist && v.is_master?
                avv.visible = false
              else
                avv.visible = avp.visible
              end
              price = avp.variants_prices.fetch(v.id.to_s, nil)
              if price
                avv.promotion_ids = avp.promotion_ids
                avv.price = price
                avv.recalculating = 10
                avv.save
              else
                # will get saved by these methods
                avv.find_eligible_promotions
                avv.cache_price
              end
            end
          else
            p.variants_including_master.each do |v|
              avv = a.account_viewable_variants.find_or_initialize_by(variant_id: v.id)
              avv.visible = false
              # will get saved by these methods
              avv.find_eligible_promotions
              avv.cache_price
            end
          end
          print '.'
        end #account each
        print 'P'
      end #product each
      puts "End Vendor: #{vendor.name}"
    end #Company each
    puts "Complete"
  end
end
