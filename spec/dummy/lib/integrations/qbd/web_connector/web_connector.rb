require 'securerandom'
require 'soap/rpc/standaloneServer'

require_dependency "#{Rails.root}/lib/integrations/qbd/web_connector/config"

require_dependency "#{Rails.root}/lib/integrations/qbd/web_connector/soap_wrapper/default"
require_dependency "#{Rails.root}/lib/integrations/qbd/web_connector/soap_wrapper/default_mapping_registry"
require_dependency "#{Rails.root}/lib/integrations/qbd/web_connector/soap_wrapper/connector_servant"
require_dependency "#{Rails.root}/lib/integrations/qbd/web_connector/soap_wrapper"

module Qbd
  module WebConnector

  end
end
