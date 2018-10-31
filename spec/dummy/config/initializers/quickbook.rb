if Rails.env == 'production'
  Quickbooks.sandbox_mode = false
else
  Quickbooks.sandbox_mode = true
end

Quickbooks.logger = Rails.logger
Quickbooks.log = true
# Pretty-printing logged xml is true by default
Quickbooks.log_xml_pretty_print = false
