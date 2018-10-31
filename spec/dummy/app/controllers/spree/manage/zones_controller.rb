module Spree
  module Manage
    class ZonesController < Spree::Manage::BaseController

      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :ensure_read_permission, only: [:index, :show]
      before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]

      def index
        @vendor = current_vendor
        @zones = @vendor.zones
      end

      def new
        @vendor = current_vendor
        @zone = @vendor.zones.new
      end

      def create
        @vendor = current_vendor
        @zone = @vendor.zones.new(zone_params)
        if @zone.save
          flash[:success] = "Zone #{@zone.name} successfully created."
          redirect_to manage_zones_path
        else
          flash[:errors] = @zone.errors.full_messages
          render :new
        end
      end

      def show
        # @vendor = current_vendor
        # @zone = @vendor.zones.find(params[:id])
        redirect_to edit_manage_zone_path(params[:id])
      end

      def edit
        @vendor = current_vendor
        @zone = @vendor.zones.find(params[:id])
      end

      def update
        @vendor = current_vendor
        @zone = @vendor.zones.find(params[:id])
        if @zone.update(zone_params)
          flash[:success] = "Zone #{@zone.name} successfully updated."
          redirect_to edit_manage_zone_path(@zone)
        else
          flash[:errors] = @zone.errors.full_messages
          render :edit
        end
      end

      def destroy
        @vendor = current_vendor
        @zone = @vendor.zones.find(params[:id])
        if @zone.destroy
          flash[:success] = "Zone removed."
        else
          flash[:error] = "Could not remove zone #{@zone.name}"
        end

        respond_to do |format|
          format.js {}
          format.html {redirect_to manage_zones_path}
        end
      end

      def load_members
        @zone = current_vendor.zones.find_by_id(params[:zone_id])
        @kind = params[:kind]
      end

      private

      def zone_params
        params.require(:zone).permit(
          :name,
          :description,
          :kind,
          :default_tax,
          country_ids: [],
          state_ids: [],
          city_ids: []
        )
      end

      def ensure_vendor
        @zone = Spree::Zone.find(params[:id])
        unless current_vendor.id == @zone.vendor_id
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to root_url
        end
      end

      def ensure_read_permission
        # piggy-backing off shipping method permissions
        if current_spree_user.cannot_read?('shipping_methods', 'settings')
          flash[:error] = 'You do not have permission to view zones'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        # piggy-backing off shipping method permissions
        if current_spree_user.cannot_read?('shipping_methods', 'settings')
          flash[:error] = 'You do not have permission to view zones'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('shipping_methods', 'settings')
          flash[:error] = 'You do not have permission to edit zones'
          redirect_to manage_zones_path
        end
      end

    end
  end
end
