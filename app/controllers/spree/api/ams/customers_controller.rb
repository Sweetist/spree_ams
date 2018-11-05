module Spree
  module Api
    module Ams
      class CustomersController < Spree::Api::CustomersController
        include Serializable
        include Requestable

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
          @accounts = @search.result.includes(:payment_terms, :orders,
                                              :contacts,
                                              :shipping_addresses,
                                              :customer)
                             .page(params[:page])
                             .per(params[:per_page])
          respond_with(@accounts)
        end

        def show
          @customer = current_vendor.customer_accounts.find(params[:id])
          respond_with(@customer)
        end

        def create
          authorize! :create, Spree::Account
          additional = {}
          additional[:customer_id] = current_api_user.id
          @customer = current_vendor.customer_accounts
                                    .new(customer_params.merge(additional))
          if @customer.save
            respond_with(@customer, status: 201, default_template: :show)
          else
            invalid_resource!(@customer)
          end
        end

        def authorize!(*_args)
          puts 'stub authorize!'
        end

        private

        def customer
          @customer ||= current_vendor.customer_accounts.find(params[:id])
        end

        def customer_params
          params.require(:customer).permit(:email, :name)
        end
      end
    end
  end
end
