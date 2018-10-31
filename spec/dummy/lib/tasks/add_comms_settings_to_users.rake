# lib/tasks/sample_data.rake
namespace :update do
  desc 'Add default comms settings data to users'
  task comms_settings: :environment do

    Spree::User.find_each do |u| 
       u.comms_settings['email']= {
        "order_confirmed": true,
        "order_revised": true,
        "order_received": true,
        "order_canceled": true,
        "order_review": true,
        "order_finalized": true,
        "daily_summary": true,
        "so_edited": true,
        "summary_send_time": '5:00PM'
      }   
      u.save!
    end 

  end
end
