module Qbd
  module WebConnector
    module SoapWrapper
      class ConnectorServant
        Methods = [
          [ "http://developer.intuit.com/serverVersion",
            "serverVersion",
            [ [:in, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "serverVersion"]],
              [:out, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "serverVersionResponse"]] ],
            { :request_style =>  :document, :request_use =>  :literal,
              :response_style => :document, :response_use => :literal,
              :faults => {} }
          ],
          [ "http://developer.intuit.com/clientVersion",
            "clientVersion",
            [ [:in, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "clientVersion"]],
              [:out, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "clientVersionResponse"]] ],
            { :request_style =>  :document, :request_use =>  :literal,
              :response_style => :document, :response_use => :literal,
              :faults => {} }
          ],
          [ "http://developer.intuit.com/authenticate",
            "authenticate",
            [ [:in, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "authenticate"]],
              [:out, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "authenticateResponse"]] ],
            { :request_style =>  :document, :request_use =>  :literal,
              :response_style => :document, :response_use => :literal,
              :faults => {} }
          ],
          [ "http://developer.intuit.com/sendRequestXML",
            "sendRequestXML",
            [ [:in, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "sendRequestXML"]],
              [:out, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "sendRequestXMLResponse"]] ],
            { :request_style =>  :document, :request_use =>  :literal,
              :response_style => :document, :response_use => :literal,
              :faults => {} }
          ],
          [ "http://developer.intuit.com/receiveResponseXML",
            "receiveResponseXML",
            [ [:in, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "receiveResponseXML"]],
              [:out, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "receiveResponseXMLResponse"]] ],
            { :request_style =>  :document, :request_use =>  :literal,
              :response_style => :document, :response_use => :literal,
              :faults => {} }
          ],
          [ "http://developer.intuit.com/connectionError",
            "connectionError",
            [ [:in, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "connectionError"]],
              [:out, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "connectionErrorResponse"]] ],
            { :request_style =>  :document, :request_use =>  :literal,
              :response_style => :document, :response_use => :literal,
              :faults => {} }
          ],
          [ "http://developer.intuit.com/getLastError",
            "getLastError",
            [ [:in, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "getLastError"]],
              [:out, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "getLastErrorResponse"]] ],
            { :request_style =>  :document, :request_use =>  :literal,
              :response_style => :document, :response_use => :literal,
              :faults => {} }
          ],
          [ "http://developer.intuit.com/closeConnection",
            "closeConnection",
            [ [:in, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "closeConnection"]],
              [:out, "parameters", ["::SOAP::SOAPElement", "http://developer.intuit.com/", "closeConnectionResponse"]] ],
            { :request_style =>  :document, :request_use =>  :literal,
              :response_style => :document, :response_use => :literal,
              :faults => {} }
          ]
        ]

        attr_accessor :integration_item
        def initialize(integration_item = nil)
          @integration_item = integration_item
        end

        # SYNOPSIS
        #   serverVersion(parameters)
        #
        # ARGS
        #   parameters      ServerVersion - {http://developer.intuit.com/}serverVersion
        #
        # RETURNS
        #   parameters      ServerVersionResponse - {http://developer.intuit.com/}serverVersionResponse
        #
        def serverVersion(parameters)
          ServerVersionResponse.new(Qbd::WebConnector.config.server_version)
        end

        # SYNOPSIS
        #   clientVersion(parameters)
        #
        # ARGS
        #   parameters      ClientVersion - {http://developer.intuit.com/}clientVersion
        #
        # RETURNS
        #   parameters      ClientVersionResponse - {http://developer.intuit.com/}clientVersionResponse
        #
        def clientVersion(parameters)
          clientVersionResult = nil

          if Qbd::WebConnector.config.minimum_web_connector_client_version && Qbd::WebConnector.config.minimum_web_connector_client_version.to_s > parameters.try(:strVersion)
            clientVersionResult = "E:This version of QuickBooks Web Connector is outdated. Version #{Qbd::WebConnector.config.minimum_web_connector_client_version} or greater is required."
          end

          ClientVersionResponse.new(clientVersionResult)
        end

        # SYNOPSIS
        #   authenticate(parameters)
        #
        # ARGS
        #   parameters      Authenticate - {http://developer.intuit.com/}authenticate
        #
        # RETURNS
        #   parameters      AuthenticateResponse - {http://developer.intuit.com/}authenticateResponse
        #
        def authenticate(parameters)
          token = SecureRandom.uuid
          result = 'nvu'

          if @integration_item.qbd_username == parameters.try(:strUserName) && @integration_item.qbd_password == parameters.try(:strPassword)
            # Move IntegrationAction from state ENQUEUED to PROCESSING
            @integration_item.start_progress_tracking
            if @integration_item.total_count > 0
              # Empty sync_id means we tried to query for item and next step is to create it.
              # By removing these on beginning of sync, we enable sync to re-query for item again
              @integration_item.integration_sync_matches.where(sync_id: '').destroy_all
              result = '' # this accesses currently opened QB file
            else
              result = 'none'
            end
          end

          AuthenticateResponse.new([token, result, true, true])
        end

        # SYNOPSIS
        #   sendRequestXML(parameters)
        #
        # ARGS
        #   parameters      SendRequestXML - {http://developer.intuit.com/}sendRequestXML
        #
        # RETURNS
        #   parameters      SendRequestXMLResponse - {http://developer.intuit.com/}sendRequestXMLResponse
        #
        def sendRequestXML(parameters)
          request_xml = @integration_item.next_action.try(:qbd_build)

          SendRequestXMLResponse.new(request_xml)
        end

        # SYNOPSIS
        #   receiveResponseXML(parameters)
        #
        # ARGS
        #   parameters      ReceiveResponseXML - {http://developer.intuit.com/}receiveResponseXML
        #
        # RETURNS
        #   parameters      ReceiveResponseXMLResponse - {http://developer.intuit.com/}receiveResponseXMLResponse
        #
        def receiveResponseXML(parameters)
          @integration_item.next_action.try(:qbd_handle, parameters.try(:response))

          ReceiveResponseXMLResponse.new(@integration_item.progress)
        end

        # SYNOPSIS
        #   connectionError(parameters)
        #
        # ARGS
        #   parameters      ConnectionError - {http://developer.intuit.com/}connectionError
        #
        # RETURNS
        #   parameters      ConnectionErrorResponse - {http://developer.intuit.com/}connectionErrorResponse
        #
        def connectionError(parameters)
          p [parameters]
          raise NotImplementedError.new
        end

        # SYNOPSIS
        #   getLastError(parameters)
        #
        # ARGS
        #   parameters      GetLastError - {http://developer.intuit.com/}getLastError
        #
        # RETURNS
        #   parameters      GetLastErrorResponse - {http://developer.intuit.com/}getLastErrorResponse
        #
        def getLastError(parameters)
          GetLastError.new(@integration_item.last_error)
        end

        # SYNOPSIS
        #   closeConnection(parameters)
        #
        # ARGS
        #   parameters      CloseConnection - {http://developer.intuit.com/}closeConnection
        #
        # RETURNS
        #   parameters      CloseConnectionResponse - {http://developer.intuit.com/}closeConnectionResponse
        #
        def closeConnection(parameters)
          @integration_item.stop_progress_tracking
          CloseConnectionResponse.new
        end

      end
    end
  end
end
