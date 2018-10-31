module Spree
  module Manage
    class StockLocationsController < Spree::Manage::BaseController
      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :ensure_read_permission, only: [:show, :index]
      before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]
      before_action :ensure_subscription_limit, only: [:new, :create, :update]

      def index
        @vendor = current_vendor
        @stock_locations = @vendor.stock_locations
      end

      def show
        @vendor = current_vendor
        @stock_location = Spree::StockLocation.find(params[:id])
        render :show
      end

      def new
        @vendor = current_vendor
        @stock_location = @vendor.stock_locations.new
        render :new
      end

      def create
        @vendor = current_vendor
        @stock_location = @vendor.stock_locations.new(stock_location_params)

        if @stock_location.save
          if @vendor.stock_locations.count == 1 && !@stock_location.default?
            @stock_location.update_columns(default: true)
          end
          flash[:success] = "Stock Location #{@stock_location.name} has been created."
          redirect_to manage_stock_location_path(@stock_location)
        else
          flash.now[:errors] = @stock_location.errors.full_messages
          render :new
        end
      end

      def edit
        @vendor = current_vendor
        @stock_location = Spree::StockLocation.find(params[:id])
        render :edit
      end

      def update
        @vendor = current_vendor
        @stock_location = Spree::StockLocation.find(params[:id])

        if @stock_location.update(stock_location_params)
          if @stock_location.default?
            @vendor.stock_locations.where('id != ?', @stock_location.id).update_all(default: false)
          end
          flash[:success] = "Stock Location #{@stock_location.name} has been updated."
          redirect_to manage_stock_location_path(@stock_location)
        else
          flash.now[:errors] = @stock_location.errors.full_messages
          render :edit
        end
      end

      def destroy
        @stock_location = Spree::StockLocation.find(params[:id])
        if current_vendor.stock_locations.count > 1 && @stock_location.destroy!
          respond_with do |format|
            format.js{ @stock_location }
            format.html{
              flash[:success] = "Stock Location #{@stock_location.name} has been deleted."
              redirect_to manage_stock_locations_path
            }
          end
        else
          respond_with do |format|
            format.js{ @stock_location }
            format.html{
              flash.now[:error] = "Could not delete stock location #{@stock_location.name}."
              redirect_to manage_stock_locations_path
            }
          end
        end
      end

      private

      def stock_location_params
        params.require(:stock_location).permit(
          :name,
          :default,
          :backorderable_default,
          :address1,
          :address2,
          :zipcode,
          :city,
          :state_id,
          :state_name,
          :country_id,
          :active
        )
      end

      def ensure_vendor
        @stock_location = Spree::StockLocation.find(params[:id])
        unless current_vendor.id == @stock_location.vendor_id
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to root_url
        end
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('stock_locations', 'inventory')
          flash[:error] = 'You do not have permission to view stock locations'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('stock_locations', 'inventory')
          flash[:error] = "You do not have permission to view stock locations"
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('stock_locations', 'inventory')
          flash[:error] = "You do not have permission to edit stock locations"
          redirect_to manage_stock_locations_path
        end
      end

      def ensure_subscription_limit
        limit = current_company.subscription_limit('stock_locations')
        unless current_company.within_subscription_limit?('stock_locations', current_company.stock_locations.active.count)
          flash[:error] = "Your subscription is limited to #{limit} stock #{'location'.pluralize(limit)}"
          redirect_to manage_stock_locations_path
        end
      end


    end
  end
end
