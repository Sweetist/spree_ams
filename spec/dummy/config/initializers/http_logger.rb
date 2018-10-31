
if Rails.env.development? && Object.const_defined?('HttpLog')
  p '!!!!!!!!!!!!! HTTP log is enabled!!!!!!!!!!!'
  HttpLog.configure do |config|
    # You can assign a different logger
    config.logger = Logger.new(STDOUT)

    # Tweak which parts of the HTTP cycle to log...
    config.log_connect   = true
    config.log_request   = true
    config.log_headers   = false
    config.log_data      = true
    config.log_status    = true
    config.log_response  = true
    config.log_benchmark = false

    # ...or log all request as a single line by setting this to `true`
    config.compact_log = false

    # Prettify the output - see below
    config.color = true

    # Limit logging based on URL patterns
    config.url_whitelist_pattern = /localhost/
    config.url_blacklist_pattern = nil
  end
end
