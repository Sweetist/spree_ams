module Spree
  module Manage
    class TaxRatesController < Spree::Manage::BaseController

      respond_to :js
      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :ensure_read_permission, only: [:index, :show]
      before_action :ensure_write_permission, only: [:new, :edit, :create, :update, :destroy]

      def index
        @vendor = current_vendor
        @search = Spree::TaxRate.joins(:tax_category).where('spree_tax_categories.vendor_id = ?', @vendor.id).ransack(params[:q])
        @all_tax_rates = @search.result.includes(:zone, :tax_category, :calculator).page(params[:page])
        render :index
      end

      def new
        @tax_rate = Spree::TaxRate.new
        @vendor = current_vendor
        @available_categories = @vendor.tax_categories
        @available_zones = @vendor.zones
        render :new
      end

      def create
        @tax_rate = Spree::TaxRate.new(tax_rate_params)
        @vendor = current_vendor
        @available_categories = @vendor.tax_categories
        @available_zones = @vendor.zones

        # using DefaultTax tax calculator by default
        @tax_rate.build_calculator(type: "Spree::Calculator::DefaultTax")

        if @tax_rate.save
          flash[:success] = "New tax rate saved"
          redirect_to manage_tax_rates_path
        else
          flash.now[:errors] = @tax_rate.errors.full_messages
          render :new
        end
      end

      def show
        redirect_to edit_manage_tax_rate_path(params[:id])
      end

      def edit
        @tax_rate = Spree::TaxRate.find(params[:id])
        @vendor = current_vendor
        @available_categories = @vendor.tax_categories
        @available_zones = @vendor.zones
      end

      def update
        @tax_rate = Spree::TaxRate.find(params[:id])
        @vendor = current_vendor
        @available_categories = @vendor.tax_categories
        @available_zones = @vendor.zones
        if @tax_rate.update(tax_rate_params)
          flash[:success] = "#{@tax_rate.name} updated"
          redirect_to manage_tax_rates_path
        else
          flash.now[:errors] = @tax_rate.errors.full_messages
          render :edit
        end
      end

      def destroy
        @tax_rate = Spree::TaxRate.find(params[:id])
        if @tax_rate.destroy!
          respond_with do |format|
            format.html do
              flash[:success] = "Tax rate #{@tax_rate.try(:name)} deleted"
              redirect_to manage_tax_rates_url
            end
            format.js do
              flash.now[:success] = "Tax rate #{@tax_rate.try(:name)} deleted"
              @tax_rate
            end
          end
        else
          respond_with do |format|
            format.html do
              flash[:error] = "Could not delete tax rate #{@tax_rate.try(:name)}"
              redirect_to manage_tax_rates_url
            end
            format.js do
              flash.now[:error] = "Could not delete tax rate #{@tax_rate.try(:name)}"
              @tax_rate = nil
            end
          end
        end
      end

      private
        def tax_rate_params
          params.require(:tax_rate).permit(
            :name,
            :amount,
            :included_in_price,
            :zone_id,
            :tax_category_id,
            :show_rate_in_label,
            :calculator_type
          )
        end

        def ensure_vendor
          @tax_rate = Spree::TaxRate.find(params[:id])
          unless current_vendor.id == @tax_rate.tax_category.try(:vendor_id)
            flash[:error] = "You don't have permission to view the requested page"
            redirect_to root_url
          end
        end

        def ensure_read_permission
          if current_spree_user.cannot_read?('tax_categories', 'settings')
            flash[:error] = 'You do not have permission to view tax rates'
            redirect_to manage_path
          end
        end

        def ensure_write_permission
          if current_spree_user.cannot_read?('tax_categories', 'settings')
            flash[:error] = 'You do not have permission to view tax rates'
            redirect_to manage_path
          elsif current_spree_user.cannot_write?('tax_categories', 'settings')
            flash[:error] = 'You do not have permission to edit tax rates'
            redirect_to manage_tax_rates_path
          end
        end

    end
  end
end
