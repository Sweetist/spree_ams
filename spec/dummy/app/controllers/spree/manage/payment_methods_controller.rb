module Spree
  module Manage
    class PaymentMethodsController < Spree::Manage::BaseController

      respond_to :js
      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :ensure_read_permission, only: [:index, :show]
      before_action :ensure_write_permission, only: [:new, :edit, :create, :update, :destroy]

      before_action :load_data
      before_action :validate_payment_method_provider, only: :create


      def index
        @vendor = current_vendor
        @payment_methods = current_vendor.payment_methods.visible
        respond_with do |format|
          format.html
          format.json { render :json => @payment_methods }
        end
      end

      def new
        @vendor = current_vendor
        @payment_method = @vendor.payment_methods.new
        render :new
      end

      def create
        @vendor = current_vendor
        @payment_method = @vendor.payment_methods.new(payment_method_params)
        #invoke_callbacks(:create, :before)
        if @payment_method.save
          #invoke_callbacks(:create, :after)
          flash[:success] = "New payment method saved"
          redirect_to edit_manage_payment_method_path(@payment_method)
        else
          #invoke_callbacks(:create, :fails)
          flash.now[:errors] = @payment_method.errors.full_messages
          render :new
        end
      end

      def edit
        @vendor = current_vendor
        @payment_method = @vendor.payment_methods.find(params[:id])
        #@payment_method_in_use = @payment_method.is_in_use?
      end

      def update
        @vendor = current_vendor
        payment_method_type = params[:payment_method].delete(:type)
        if @payment_method['type'].to_s != payment_method_type
          @payment_method.update_columns(type: payment_method_type, updated_at: Time.current)
          @payment_method = @vendor.payment_methods.find(params[:id])
          update_params = params[ActiveModel::Naming.param_key(@payment_method)] || {}
        end
        update_params = params[ActiveModel::Naming.param_key(@payment_method)] || {}
        attributes = payment_method_params.merge(update_params)
        attributes.each do |k,v|
          if k.include?("password") && attributes[k].blank?
            attributes.delete(k)
          end
        end
        if @payment_method.update(attributes)
          #invoke_callbacks(:update, :after)
          flash[:success] = Spree.t(:successfully_updated, :resource => Spree.t(:payment_method))
          redirect_to edit_manage_payment_method_path(@payment_method)
        else
          flash.now[:errors] = @payment_method.errors.full_messages
          #invoke_callbacks(:update, :fails)
          render :edit
        end

      end

      def destroy
        @vendor = current_vendor
        @payment_method = @vendor.payment_methods.find(params[:id])
        if @payment_method.destroy
          respond_with do |format|
            format.html do
              flash[:success] = "Payment method #{@payment_method.try(:name)} deleted"
              redirect_to manage_payment_methods_path
            end
            format.js do
              flash.now[:success] = "Payment method #{@payment_method.try(:name)} deleted"
            end
          end
        else
          respond_with do |format|
            format.html do
              flash[:error] = "Could not delete payment method #{@payment_method.try(:name)}"
              redirect_to :back
            end
            format.js do
              flash.now[:error] = "Could not delete payment method #{@payment_method.try(:name)}"
              @payment_method = nil
            end
          end
        end
      end

      private

      def payment_method_params
        params.require(:payment_method).permit!
      end

      # payment gateway
      def load_data
        @providers = Sweet::Application.config.x.payment_methods.map do |provider|
          [provider.name.demodulize, provider.name]
        end.sort
      end

      def validate_payment_method_provider
        valid_payment_methods = Sweet::Application.config.x.payment_methods.map(&:to_s)
        if !valid_payment_methods.include?(params[:payment_method][:type])
          flash[:error] = Spree.t(:invalid_payment_provider)
          redirect_to new_manage_payment_method_path
        end
      end

      def ensure_vendor
        @payment_method = Spree::PaymentMethod.find(params[:id])
        unless current_vendor.id == @payment_method.vendor_id
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to root_url
        end
      end

      def ensure_read_permission
        unless current_spree_user.can_read?('payment_methods', 'settings')
          flash[:error] = 'You do not have permission to view payment methods'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if !current_spree_user.can_read?('payment_methods', 'settings')
          flash[:error] = 'You do not have permission to view payment methods'
          redirect_to manage_path
        elsif !current_spree_user.can_write?('payment_methods', 'settings')
          flash[:error] = 'You do not have permission to edit payment methods'
          redirect_to manage_payment_methods_path
        end
      end

    end
  end
end
