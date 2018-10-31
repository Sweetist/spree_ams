namespace :db do
  desc 'Fill integration type'
  task fill_integration_type: :environment do
    Spree::Company.vendor_companies.each do |vendor|
      fill_integration_type(vendor)
    end
  end

  def fill_integration_type(vendor)
    integrations = Spree::Integration.available_vendors_integrations(vendor)
    integrations.each do |integaration|
      next unless integaration[:integrations].any?
      type = integaration[:integration_type]
      integaration[:integrations].map do |i|
        i.update_column(:integration_type, type)
        i.sales_channel = i.default_sales_channel
        i.save!
      end
    end
  end
end
