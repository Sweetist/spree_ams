module Spree
  module Manage
    class ShippingGroupsController < Spree::Manage::BaseController
      respond_to :js

      before_action :get_class_name_display_text
      before_action :ensure_read_permission, only: [:index]
      before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]

      def index
        @shipping_groups = @vendor.shipping_groups
        @can_edit = current_spree_user.can_write?('shipping_groups', 'settings')
        render :index
      end

      def new
        @shipping_group = @vendor.shipping_groups.new
        render :new
      end

      def create
        @shipping_group = @vendor.shipping_groups.new

        if @shipping_group.update(shipping_group_params)
          flash[:success] = "#{@vendor.display_shipping_group_class} successfully created."
          redirect_to manage_shipping_groups_path
        else
          flash.now[:errors] = @shipping_group.errors.full_messages
          render :new
        end
      end

      def edit
        @shipping_group = @vendor.shipping_groups.find(params[:id])
        render :edit
      end

      def update
        @shipping_group = @vendor.shipping_groups.find(params[:id])

        if @shipping_group.update(shipping_group_params)
          flash[:success] = "#{@vendor.display_shipping_group_class} successfully updated."
          redirect_to manage_shipping_groups_path
        else
          flash.now[:errors] = @shipping_group.errors.full_messages
          render :edit
        end
      end

      def show
        # This is currently only being used for partials via js, if html response
        # is added, then this should be added to ensure_read_permission and to
        # controller test
        @shipping_group = @vendor.shipping_groups.find(params[:id])

        respond_with do |format|
          format.js do
            @shipping_group
            render :show
          end
        end
      end

      def destroy
        @shipping_group = @vendor.shipping_groups.find(params[:id])

        if @shipping_group.destroy!
          @shipping_group.accounts.update_all(shipping_group_id: nil)
          respond_with do |format|

						format.html do
						  flash[:success] = "#{@vendor.display_shipping_group_class} #{@shipping_group.try(:name)} deleted"
  						redirect_to manage_shipping_groups_path
            end
						format.js {@shipping_group}
					end
        else
          respond_with do |format|
						format.html do
						  flash[:error] = "Could not delete #{@vendor.display_shipping_group_class} #{@shipping_group.try(:name)}"
  						redirect_to manage_shipping_groups_path
            end
						format.js do
				      @shipping_group = nil
						end
					end
        end
      end

      private

      def shipping_group_params
        params.require(:shipping_group).permit(
          :name,
          :is_default,
          :deliverable_days,
          :delivery_on_sunday,
          :delivery_on_monday,
          :delivery_on_tuesday,
          :delivery_on_wednesday,
          :delivery_on_thursday,
          :delivery_on_friday,
          :delivery_on_saturday
        )
      end

      def get_class_name_display_text
        @vendor = current_vendor
        @display_shipping_group_class ||= @vendor.display_shipping_group_class
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('shipping_groups', 'settings')
          flash[:error] = "You do not have permission to view #{@vendor.display_shipping_group_class.downcase}s"
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('shipping_groups', 'settings')
          flash[:error] = "You do not have permission to view #{@vendor.display_shipping_group_class.downcase}s"
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('shipping_groups', 'settings')
          flash[:error] = "You do not have permission to edit #{@vendor.display_shipping_group_class.downcase}s"
          redirect_to manage_shipping_groups_path
        end
      end

    end
  end
end
