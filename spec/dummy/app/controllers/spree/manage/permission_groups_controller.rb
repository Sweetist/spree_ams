module Spree
  module Manage

    class PermissionGroupsController < Spree::Manage::BaseController
      respond_to :js
      before_action :ensure_company, only: [:edit, :update, :destroy]
      before_action :ensure_update_permission, only: [:edit, :update]
      before_action :ensure_create_destroy_permission, only: [:new, :create, :destroy]

      def index
        @company = current_spree_user.company
        @permission_groups = @company.permission_groups
        @permission_groups_default = Spree::PermissionGroup.where(company_id: nil)
        @advanced_user_rights_allowed = @company.subscription_includes?('advanced_user_rights')
        if !@company.subscription_includes?('basic_user_rights')
          render :show_upgrade
        else
          render :index
        end
      end

      def new
        @vendor = current_vendor
        @company = current_spree_user.company
        @permission_group = @company.permission_groups.new
        if !@company.subscription_includes?('advanced_user_rights')
          render :show_upgrade
        else
          render :new
        end
      end

      def create
        @company = current_spree_user.company
        @permission_group = @company.permission_groups.new

        if @permission_group.update(permission_group_params)
          flash[:success] = 'New permission group has been saved'
          redirect_to manage_permission_groups_path
        else
          flash.now[:errors] = @permission_group.errors.full_messages
          render :new
        end
      end

      def edit
        @company = current_spree_user.company
        @permission_group = @company.permission_groups.find(params[:id])
        if @permission_group.name == Spree.t(:owner_access)
          flash[:warning] = 'This is the Owner Access Permission Group and cannot be edited'
          redirect_to manage_permission_group_path(params[:id])
        else
          render :edit
        end
      end

      def show
        @company = current_spree_user.company
        @permission_group = Spree::PermissionGroup.find(params[:id])
        render :show
      end

      def update
        @company = current_spree_user.company
        @permission_group = @company.permission_groups.find(params[:id])
        if @permission_group.update(permission_group_params)
          flash[:success] = 'Permission group has been updated'
          redirect_to manage_permission_groups_path
        else
          flash.now[:errors] = @permission_group.errors.full_messages
          render :edit
        end
      end

      def destroy
        @company = current_spree_user.company
        @permission_group = @company.permission_groups.find_by_id(params[:id])

        if (@permission_group.try(:name) != Spree.t(:owner_access)) && @permission_group.destroy!
          @company.users.where(permission_group_id: params[:id]).update_all(permission_group_id: nil)
          respond_with do |format|
            format.html do
              flash[:success] = 'Permission group deleted'
              redirect_to manage_permission_groups_path
            end
            format.js {@permission_group}
          end
        else
          respond_with do |format|
            format.html do
              flash[:error] = 'Could not delete permission group'
              redirect_to manage_permission_groups_path
            end
            format.js do
              @permission_group = nil
            end
          end
        end
      end

      private

      def permission_group_params
        params.require(:permission_group).permit(
          :name,
          :is_default,
          :permission_group_id,
          :permission_invoice,
          :permission_order_basic_options,
          :permission_order_payments,
          :permission_order_edit_line_item,
          :permission_order_approve_ship_receive,
          :permission_order_manual_adjustment,
          :permission_purchase_orders_basic_options,
          :permission_purchase_orders_vendors,
          :permission_standing_orders_basic_options,
          :permission_standing_orders_standing_orders_schedule,
          :permission_products_catalog,
          :permission_products_categories,
          :permission_products_option_values,
          :permission_inventory_basic_options,
          :permission_inventory_stock_locations,
          :permission_customers_basic_options,
          :permission_customers_users,
          :permission_users_basic_options,
          :permission_users_user_adjust,
          :permission_promotions,
          :permission_reports_basic_options,
          :permission_reports_production_reports,
          :permission_settings_integrations,
          :permission_settings_permission_categories,
          :permission_settings_tax_categories,
          :permission_settings_payment_methods,
          :permission_settings_shipping_categories,
          :permission_settings_shipping_methods,
          :permission_settings_shipping_groups,
          :permission_company
        )
      end

      def ensure_company
        @permission_group = current_company.permission_groups.find_by_id(params[:id])
        unless @permission_group
          flash[:error] = 'You do not have permission view the requested page'
          redirect_to manage_permission_groups_path
        end
      end

      def ensure_update_permission
        if !current_company.subscription_includes?('basic_user_rights')
          flash[:error] = 'Your current subscription does not allow adding or removing permission groups. Please contact Sweet to upgrade your plan.'
          redirect_to  manage_permission_groups_path
        elsif current_spree_user.cannot_read?('company')
          flash[:error] = 'You do not have permission to view company settings'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('company')
          flash[:error] = 'You do not have permission to edit company settings'
          redirect_to manage_permission_groups_path
        end
      end

      def ensure_create_destroy_permission
        if !current_company.subscription_includes?('advanced_user_rights')
          flash[:error] = 'Your current subscription does not allow adding or removing permission groups. Please contact Sweet to upgrade your plan.'
          redirect_to manage_permission_groups_path
        elsif current_spree_user.cannot_read?('company')
          flash[:error] = 'You do not have permission to view company settings'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('company')
          flash[:error] = 'You do not have permission to edit company settings'
          redirect_to manage_permission_groups_path
        end
      end
    end
  end
end
