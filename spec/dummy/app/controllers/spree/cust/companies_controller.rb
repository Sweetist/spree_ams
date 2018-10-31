module Spree
  module Cust
    class CompaniesController < Spree::Cust::CustomerHomeController


      def edit
        @company = current_customer
        session[:customer_id] = @company.id
        render :edit
      end

      def show
        @company = current_customer
        @users = @company.users.order('firstname ASC')
      end

      def update
        @company = current_customer
        session[:customer_id] = @company.id
        if @company.update(company_params)
          flash[:success] = "Company has been updated!"
          redirect_to edit_my_company_path
        else
          flash[:errors] = @company.errors.full_messages
          render :edit
        end
      end

      private

      def company_params
        params.require(:company).permit(
        :name,
        :email,
        :time_zone)
      end

    end
  end
end
