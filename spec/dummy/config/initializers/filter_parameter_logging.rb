# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters = [
  :password,
  :password_confirmation,
  :verification_value,
  :payment_source,
  :credit_card,
  :token,
  :api_key,
  :secret
]
