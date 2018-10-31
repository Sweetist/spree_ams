module Spree
  module Api
    class CustomerTypesController < Spree::Api::BaseController

      def index
        @customer_types = Spree::CustomerType.all
        respond_with(@customer_types)
      end

      def show
        @customer_type = Spree::CustomerType.find(params[:id])
        respond_with(@customer_type)
      end

      private

      def customer_type
        @customer_type ||= Spree.customer_type_class.accessible_by(current_ability, :read).find(params[:id])
      end

      def customer_type_params
        params.require(:customer_type).permit(permitted_customer_type_attributes)
      end

    end
  end
end
