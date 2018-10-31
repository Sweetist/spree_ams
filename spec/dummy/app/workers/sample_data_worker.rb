class SampleDataWorker
  include Sidekiq::Worker

  def perform(company_id, skip = {})
    skip = skip.with_indifferent_access
    company = Spree::Company.friendly.find(company_id)
    company.setup_default_data unless skip[:default_data]
    company.setup_sample_data(skip) unless skip[:sample_data]
  rescue ActiveRecord::RecordNotFound
    true # moving on if company has been removed from DB
  end
end
