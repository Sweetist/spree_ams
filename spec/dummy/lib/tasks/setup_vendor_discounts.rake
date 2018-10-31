namespace :db do

  desc 'Setup flatrate category(taxon) promotions'
  task :create_flat_rate_category_promotions, [:vendor_name, :currency, :file_path] => :environment do |t, args|
    # Setting stdout to be true so we can output without line breaks using 'print'
    $stdout.sync = true
    # using sample csv file_path
    # args.with_defaults(currency: 'USD', file_path: File.expand_path("../templates/import_flat_rate_category_promotions_sample.csv", __FILE__), remote: false)
    args.with_defaults(currency: 'USD')
    # See https://github.com/tilo/smarter_csv for full list of options and defaults
    options = {chunk_size: 100}

    puts "Let's Make a DEAL!"
    vendor = Spree::Company.find_by_name(args.vendor_name)
    promos = []
    if vendor
      row_counter = 2 # starting row
      require 'open-uri'
      file_location = "#{args.file_path}" #expects http://... as the file_path
      open(file_location, 'r:utf-8') do |f| #remove this open(file_location) if using local file
        SmarterCSV.process(f, options) do |chunk|
          chunk.each do |promo_row|
            if (row_counter) % 25 == 0
              puts "\n"
              puts "Row #{row_counter}\n"
            end
            row_counter += 1
            if promo_row[:discount_amount] && promo_row[:product_category]

              account = vendor.customer_accounts.where(fully_qualified_name: promo_row[:account_full_name]).first
              taxonomy = Spree::Taxonomy.where(vendor_id: vendor.id).first
              taxonomy ||= vendor.taxonomies.create(name: vendor.name)
              taxon = taxonomy.try(:root)
              promo_row[:product_category].to_s.split(">").map(&:strip).each do |taxon_string|
                parent_id = taxon.try(:id)
                taxon = Spree::Taxon.where('name ILIKE ?', taxon_string).where(parent_id: parent_id).first
              end
              if promo_row[:discount_amount] < 0
                promo_name = "#{taxon.try(:name)}: #{Spree::Money.new(promo_row[:discount_amount].abs, currency: args.currency)} Discount"
              else
                promo_name = "#{taxon.try(:name)}: #{Spree::Money.new(promo_row[:discount_amount].abs, currency: args.currency)} Upcharge"
              end

              advertise = promo_row[:show_base_price] || false
              promo = vendor.promotions.find_by_name(promo_name)
              if promo && promo.advertise == advertise
                account_rule = promo.rules.find_by_type("Spree::Promotion::Rules::Account")
                account_rule.accounts << account if account && !account_rule.account_ids.include?(account.id)
                promos << promo unless promos.include?(promo)
              elsif promos.any?{|promo| promo.name == promo_name}
                promo = promos.select{|promotion| promotion.name == promo_name}.first
                account_rule = promo.rules.select{|rule| rule.type == "Spree::Promotion::Rules::Account"}.first
                account_rule.accounts << account if account && !account_rule.account_ids.include?(account.id)
              else
                promo = vendor.promotions.new(name: promo_name, advertise: advertise)
                account_rule = promo.rules.new(type: "Spree::Promotion::Rules::Account")
                account_rule.accounts << account if account
                # account_rule.save
                taxon_rule = promo.rules.new(type: "Spree::Promotion::Rules::Taxon")
                taxon_rule.taxons << taxon if taxon
                # taxon_rule.save
                action = promo.actions.new(type: "Spree::Promotion::Actions::CreateItemAdjustments")

                # action.calculator.destroy!

                action.build_calculator(type: "Spree::Calculator::FlatRate",
                   preferences: {amount: BigDecimal.new(promo_row[:discount_amount] * -1, 8),
                     currency: args.currency
                    }
                  )
                # action.save
                promos << promo
              end

              # print promo.save ? "." : "E"


            end
          end
        end
        promos.each {|promo| promo.save }
      end
    else
      puts "Could not find vendor with name #{args.vendor_name}"
    end
    puts "All done."
  end
end
