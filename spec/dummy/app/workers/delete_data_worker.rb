class DeleteDataWorker
  include Sidekiq::Worker

  def perform(company_id, delete_data_params)
    company = Spree::Company.friendly.find(company_id)
    errors = []
    Spree::Company::Resets::RESET_EVENT_ORDER.each do |event|
      if delete_data_params["destroy_#{event}"].to_bool
        begin
          company.send("destroy_all_#{event}")
        rescue Exceptions::DataIntegrity => e
          errors << e.message
        end
      end
    end

    Spree::VendorMailer.delete_data_email(company_id, errors).deliver_now
  end
end
