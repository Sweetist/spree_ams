# Load the Rails application.
require File.expand_path('../application', __FILE__)

ActionMailer::Base.smtp_settings = { 
  :user_name => ENV["SENDGRID_USERNAME"],
  :password => ENV["SENDGRID_PW"],
  :domain => ENV["SMTP_DOMAIN"],
  :address => 'smtp.sendgrid.net',
  :port => 587,
  :authentication => :plain,
  :enable_starttls_auto => true
}

# Initialize the Rails application.
Sweet::Application.initialize!
