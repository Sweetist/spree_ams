namespace :db do

  desc 'Create customer viewable products'
  task :visible_avvs, [:vendor_name, :file_path] => :environment do |t, args|

    # Setting stdout to be true so we can output without line breaks using 'print'
    $stdout.sync = true

    # uncommenting this will use the template as the default file_path if none is provided
    # args.with_defaults(file_path: File.expand_path("../templates/import_viewable_products_sample.csv", __FILE__))

    # See https://github.com/tilo/smarter_csv for full list of options and defaults
    options = {chunk_size: 100, row_sep: "\n", col_sep: ","}

    vendor = Spree::Company.find_by_name(args.vendor_name)
    invalid_skus = {}
    invalid_customers = {}
    if vendor
      SmarterCSV.process(args.file_path, options) do |chunk|
        chunk.each do |viewable_product_row|

          acc_names = viewable_product_row[:customer_name].to_s.split('|').map{|name| name.strip }
          accounts = vendor.customer_accounts.where(fully_qualified_name: acc_names)

          if acc_names.count > accounts.count
            acc_names.each do |name|
              invalid_customers[name] = true unless accounts.any?{|a| a.fully_qualified_name == name}
            end
          end

          variant = vendor.variants_including_master.find_by_sku(viewable_product_row[:sku])
          invalid_skus[viewable_product_row[:sku]] = true unless variant

          if accounts.present? && variant.present?
            Spree::AccountViewableVariant.where(
              account_id: accounts.ids,
              variant_id: variant.id
            ).update_all(visible: true)
            print "."
          else
            print "E"
          end
        end
      end
      puts "Complete"
      puts "Could not find accounts for #{invalid_customers.count} customers" unless invalid_customers.blank?
      invalid_customers.keys.each do |customer|
        puts customer
      end
      puts "Could not find products for #{invalid_skus.count} skus" unless invalid_skus.blank?
      invalid_skus.keys.each do |sku|
        puts sku
      end
    else
      puts "Could not find vendor with name #{args.vendor_name}"
    end
  end

end
