module Spree
  module Api
      class CustomersController < Spree::Api::BaseController

        rescue_from Spree::Core::DestroyWithOrdersError, with: :error_during_processing

        def index
=begin
          if params[:ids]
            @customers = customer_scope.where(id: params[:ids].split(",").flatten)
          else
            @customers = customer_scope.ransack(params[:q]).result
          end

          @customers = @customers.distinct.page(params[:page]).per(params[:per_page])
          expires_in 15.minutes, :public => true
          headers['Surrogate-Control'] = "max-age=#{15.minutes}"
          respond_with(@customers)
=end
          # @customers = Spree::Customer.all
          @search = current_vendor.customer_accounts.ransack(params[:q])
          @accounts = @search.result.includes(:payment_terms, :orders, :contacts, :shipping_addresses, :customer).page(params[:page])
          respond_with(@accounts)
        end

        def show
          @customer = current_vendor.customer_accounts.find(params[:id])
          respond_with(@customer)
        end

        def new
        end

        def create
          authorize! :create, Spree.customer_class
          @customer = Spree.customer_class.new(customer_params)
          if @customer.save
            respond_with(@customer, :status => 201, :default_template => :show)
          else
            invalid_resource!(@customer)
          end
        end

        def update
          authorize! :update, customer
          if customer.update_attributes(customer_params)
            respond_with(customer, :status => 200, :default_template => :show)
          else
            invalid_resource!(customer)
          end
        end

        def destroy
          authorize! :destroy, customer
          customer.destroy
          respond_with(customer, :status => 204)
        end

        private

        def customer
          @customer ||= Spree.customer_class.accessible_by(current_ability, :read).find(params[:id])
        end

        def customer_params
          params.require(:customer).permit(permitted_customer_attributes)
# |
#                                         [bill_address_attributes: permitted_address_attributes,
 #                                         ship_address_attributes: permitted_address_attributes)
        end

      end
  end
end
