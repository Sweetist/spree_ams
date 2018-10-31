module Spree
  module Manage
    class CustomerTypesController < Spree::Manage::BaseController

      before_action :ensure_read_permission, only: [:index, :show]
      before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]

      def index
        @vendor = current_vendor
        @customer_types = @vendor.customer_types.includes(accounts: :customer)
        render :index
      end

      def show
        redirect_to edit_manage_customer_type_path(params[:id])
      end

      def new
        @vendor = current_vendor
        @customer_type = @vendor.customer_types.new
        render :new
      end

      def create
        @vendor = current_vendor
        @customer_type = @vendor.customer_types.new(customer_type_params)
        if @customer_type.save
          flash[:success] = 'New customer type saved'
          redirect_to manage_customer_types_path
        else
          flash.now[:errors] = @customer_type.errors.full_messages
          render :new
        end
      end

      def edit
        @vendor = current_vendor
        @customer_type = @vendor.customer_types.find(params[:id])
        render :edit
      end

      def update
        @vendor = current_vendor
        @customer_type = @vendor.customer_types.find(params[:id])
        if @customer_type.update(customer_type_params)
          flash[:success] = 'Customer type updated'
          redirect_to manage_customer_types_path
        else
          flash.now[:errors] = @customer_type.errors.full_messages
          render :edit
        end
      end

      def destroy
        @vendor = current_vendor
        @customer_type = @vendor.customer_types.find(params[:id])
        if @customer_type.destroy
          flash[:success] = 'Customer type deleted'
        else
          flash[:error] = 'Could not remove customer type'
        end
        redirect_to manage_customer_types_path
      end

      private

      def customer_type_params
        params.require(:customer_type).permit(:name)
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = 'You do not have permission to view company settings'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = 'You do not have permission to view company settings'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('company')
          flash[:error] = 'You do not have permission to edit company settings'
          redirect_to manage_customer_types_path
        end
      end

    end
  end
end
