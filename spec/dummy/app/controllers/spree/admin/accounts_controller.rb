module Spree
  module Admin
    class AccountsController < ResourceController


      def index
        @search = Spree::Account.ransack(params[:q])
        @accounts = @search.result.order('name ASC').page(params[:page])
        respond_with(:admin, @accounts)
      end

      def show
        redirect_to edit_admin_account_path(@account)
      end

      def new
        @account = Spree::Account.new
        render :new
      end

      def create
        @account = Spree::Account.new(account_params)
        if @account.save
          flash.now[:success] = flash_message_for(@account, :successfully_created)
          render :edit
        else
          render :new
        end
      end

      def update
        if @account.update(account_params)
          flash.now[:success] = Spree.t(:account_updated)
        end

        render :edit
      end

			protected

			private

      def account_params
				params.require(:account).permit(
          :name,
          :email,
          :vendor_id,
          :customer_id,
          :parent_id
        )
      end
		end
	end
end
