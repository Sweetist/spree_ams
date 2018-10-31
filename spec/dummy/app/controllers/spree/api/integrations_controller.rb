module Spree
  module Api
    class IntegrationsController < Spree::Api::BaseController

      before_action :authorize_for_order, if: Proc.new { order_token.present? }, except: ['execute']
      before_action :authenticate_user, except: ['execute']
      before_action :load_user_roles, except: ['execute']
      before_action :set_paper_trail_whodunnit

      def user_for_paper_trail
        ii = Spree::IntegrationItem.where(id: params.fetch(:integration_id, nil)).first
        ii.present? ? ii.integration_key : "Integrations API"
      end

      def order_status
        integration_item = Spree::IntegrationItem.where(id: params.fetch(:integration_id)).first
        order = Spree::Order.where(number: params.fetch(:order)).first
        if !integration_item.nil? and !order.nil?
          action = Spree::IntegrationAction.where(integrationable: order, integration_item: integration_item, id: params.fetch(:action_id)).order(:id).last
          if action
            action.execution_count += 1
            action.status = params.fetch(:status) ? 10 : -1
            action.execution_log = params.fetch(:log) if action.status == -1
            action.processed_at = Time.current
            action.save
            render json: params.fetch(:debug, false) == true ? { message: 'OK' }.merge({ params: params, action: action }) : { message: 'OK' }
          else
            render json: params.fetch(:debug, false) == true ? { message: 'Unable to find unfinished sync action' }.merge({ params: params }) : { message: 'Unable to find unfinished sync action' }
          end
        else
          render json: params.fetch(:debug, false) == true ? { message: 'Missing Order ID' }.merge({ params: params }) : { message: 'Missing Order ID' }
        end
      rescue Exception => e
        render json: { message: e.message }
      end

      def execute

        # for post requests, the payload can sometimes override the url params,
        # so we are also looking at the request URL if the params[:name] is nil
        # this is important for the sweetist integration
        if params[:name]
          method_name = params[:name]
        elsif request.env['REQUEST_URI'].partition('?').last.partition('=').first == "name"
          method_name = request.env['REQUEST_URI'].partition('?').last.partition('=').last
        else
          # there is no method name coming in so we should return an error
          return 500
        end

        integration_item = Spree::IntegrationItem.find(params.fetch(:integration_id))
        execution = integration_item.public_execute(method_name, request, params)
        puts "#{execution[:xml]}" unless Rails.env.test?
        respond_to do |format|
          format.xml { render xml: execution.fetch(:xml), content_type: 'text/xml', status: execution.fetch(:status, 200) }
          format.html { render xml: execution.fetch(:xml), content_type: 'text/xml' }
          format.json { render json: execution.fetch(:json), content_type: 'text/json' }
        end
        # render xml: execution.fetch(:xml), content_type: 'text/xml'
      end

    end
  end
end
