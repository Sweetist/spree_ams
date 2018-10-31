module Spree
  module Api
      class CompaiesController < Spree::Api::BaseController

        rescue_from Spree::Core::DestroyWithOrdersError, with: :error_during_processing

        def index
          @companies = Spree::Company.all
          respond_with(@companies)
        end

        def show
          @company = Spree::Company.find(params[:id])
          respond_with(@company)
        end

        def new
        end

        def create
          authorize! :create, Spree.company_class
          @company = Spree.company_class.new(company_params)
          if @company.save
            respond_with(@company, :status => 201, :default_template => :show)
          else
            invalid_resource!(@company)
          end
        end

        def update
          authorize! :update, company
          if company.update_attributes(company_params)
            respond_with(company, :status => 200, :default_template => :show)
          else
            invalid_resource!(company)
          end
        end

        def destroy
          authorize! :destroy, company
          company.destroy
          respond_with(company, :status => 204)
        end

        private

        def company
          @company ||= Spree.company_class.accessible_by(current_ability, :read).find(params[:id])
        end

        def company_params
          params.require(:company).permit(permitted_company_attributes)
# |
#                                         [bill_address_attributes: permitted_address_attributes,
 #                                         ship_address_attributes: permitted_address_attributes)
        end

      end
  end
end
