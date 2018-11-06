module Spree
  module Api
    module Ams
      class OrdersController < Spree::Api::OrdersController
        include Serializable
        include Requestable

        def order_id
          super || params[:id]
        end

        def create
          authorize! :create, Spree::Order
          order_user = if @current_user_roles.include?('admin') || @current_user_roles.include?('vendor') && order_params[:user_id]
            Spree.user_class.find(order_params[:user_id])
          else
            current_api_user
          end

          import_params = if @current_user_roles.include?("admin") || @current_user_roles.include?('vendor')
            params[:order].present? ? params[:order].permit! : {}
          else
            order_params
          end

          import_params['vendor_id'] = current_vendor.id
          @order = Spree::Core::Importer::Order.import(order_user, import_params)
          respond_with(@order, default_template: :show, status: 201)
        end
      end
    end
  end
end
