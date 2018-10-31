module Spree
  module Api
      class AccountsController < Spree::Api::BaseController

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
          @accounts = @current_api_user.company.customer_accounts
          respond_with(@accounts)
        end

        def show
          @account = @current_api_user.company.customer_accounts.find(params[:id])
          respond_with(@account)
        end
=begin
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
=end
        private

        def account
          @account ||= Spree.account_class.accessible_by(current_ability, :read).find(params[:id])
        end

        def account_params
          params.require(:account).permit(permitted_account_attributes)
# |
#                                         [bill_address_attributes: permitted_address_attributes,
 #                                         ship_address_attributes: permitted_address_attributes)
        end

      end
  end
end
