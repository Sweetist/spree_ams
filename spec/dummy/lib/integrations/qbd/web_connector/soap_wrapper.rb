module Qbd
  module WebConnector
    module SoapWrapper

      def self.route(request, integration_item)
        @router = ::SOAP::RPC::Router.new('ConnectorServant')
        @router.mapping_registry = DefaultMappingRegistry::EncodedRegistry
        @router.literal_mapping_registry = DefaultMappingRegistry::LiteralRegistry
        servant = ConnectorServant.new(integration_item)
        ConnectorServant::Methods.each do |definitions|
          opt = definitions.last
          if opt[:request_style] == :document
            @router.add_document_operation(servant, *definitions)
          else
            @router.add_rpc_operation(servant, *definitions)
          end
        end
        @connection_data = ::SOAP::StreamHandler::ConnectionData.new
        @connection_data.receive_string = request.raw_post
        @connection_data.receive_contenttype = request.content_type
        @connection_data.soapaction = nil
        @router.external_ces = nil
        response_data = @router.route(@connection_data)
        response_data.send_string
      end

    end
  end
end
