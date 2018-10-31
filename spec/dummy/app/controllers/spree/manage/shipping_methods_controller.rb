module Spree
  module Manage
    class ShippingMethodsController < Spree::Manage::BaseController

      respond_to :js
      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :ensure_read_permission, only: [:index, :show]
      before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]

      def index
        @vendor = current_vendor
        @shipping_methods = @vendor.shipping_methods.distinct
        render :index
      end

      def show
        @vendor = current_vendor
        @shipping_method = @vendor.shipping_methods.find(params[:id])
        render :show
      end

      def new
        @vendor = current_vendor
        @shipping_method = Spree::ShippingMethod.new
        @shipping_method.build_calculator
        @shipping_categories = @vendor.shipping_categories.order('name ASC')
        render :new
      end

      def create
        @vendor = current_vendor
        @shipping_method = Spree::ShippingMethod.new(shipping_method_params)
        @shipping_method.build_calculator(
          type: params.fetch(:calculator,{}).fetch(:type, "Spree::Calculator::Shipping::FlatRate"),
          preferences: calculator_preferences
        )
        @shipping_categories = @vendor.shipping_categories.order('name ASC')
        params[:shipping_method][:display_on] ||= "Both"
        if @shipping_method.save(shipping_method_params)
          flash[:success] = "New shipping method saved"
          redirect_to manage_shipping_methods_url
        else
          flash.now[:errors] = @shipping_method.errors.full_messages
          render :new
        end
      end

      def edit
        @vendor = current_vendor
        @shipping_method = Spree::ShippingMethod.find(params[:id])
        @shipping_categories = @vendor.shipping_categories.order('name ASC')
        render :edit
      end

      def show
        @vendor = current_vendor
        @shipping_method = Spree::ShippingMethod.find(params[:id])
        @shipping_categories = @vendor.shipping_categories.order('name ASC')
        render :show
      end

      def update
        @vendor = current_vendor
        @shipping_method = Spree::ShippingMethod.find(params[:id])
        @shipping_categories = @vendor.shipping_categories.order('name ASC')

        @calculator = @shipping_method.calculator
        calculator_preferences
        if @calculator.update(
            type: params.fetch(:calculator,{}).fetch(:type, "Spree::Calculator::Shipping::FlatRate"),
            preferences: calculator_preferences
          ) && @shipping_method.update(shipping_method_params)

          flash[:success] = "Shipping method updated"
          redirect_to manage_shipping_methods_url
        else
          flash.now[:errors] = @shipping_method.errors.full_messages
          render :edit
        end
      end

      def destroy
        @shipping_method = Spree::ShippingMethod.find(params[:id])

        if @shipping_method.destroy!
          respond_with do |format|
            format.html do
              flash[:success] = "Shipping method #{@shipping_method.try(:name)} deleted"
              redirect_to manage_shipping_methods_url
            end
            format.js {@shipping_method}
          end
        else
          respond_with do |format|
            format.html do
              flash[:error] = "Could not delete shipping method #{@shipping_method.try(:name)}"
              redirect_to manage_promotion_methods_url
            end
            format.js {@shipping_method = nil}
          end
        end

      end

      private

      def ensure_vendor
        @shipping_method = Spree::ShippingMethod.find(params[:id])
        unless current_vendor.shipping_methods.find_by_id(@shipping_method.id)
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to root_url
        end
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('shipping_methods', 'settings')
          flash[:error] = 'You do not have permission to view shipping methods'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('shipping_methods', 'settings')
          flash[:error] = 'You do not have permission to view shipping methods'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('shipping_methods', 'settings')
          flash[:error] = 'You do not have permission to edit shipping methods'
          redirect_to manage_shipping_methods_path
        end
      end

      def shipping_method_params
        params.require(:shipping_method).permit(
          :name, :display_on, :tax_category_id, :code, :calculator_type,
          :rate_tbd, zone_ids:[], shipping_category_ids:[]
        )
      end

      def calculator_params
        params.require(:calculator).permit(
          :type, preferences:[:amount, :currency, :flat_percent,
          :first_item, :additional_item, :max_items,
          :minimal_amount, :normal_amount, :discount_amount]
        ) rescue {}
      end

      def calculator_preferences
        preferences = {}
        calc_params = calculator_params
        if calc_params.empty?
          calc_params[:preferences] = {}
          calc_params[:preferences][:amount] = 0
          calc_params[:preferences][:currency] = current_vendor.try(:currency)
        end

        calc_params[:preferences].each do |k, v|
          unless v.blank?
            preferences[k.to_sym] = (k.to_sym == :currency) ? v : v.to_d
          end
        end

        preferences
      end

    end
  end
end
