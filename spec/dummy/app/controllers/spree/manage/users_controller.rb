module Spree
  module Manage
    class UsersController < Spree::Manage::BaseController
      respond_to :js
      before_action :ensure_read_permission, only: [:show, :index]
      before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]
      before_action :ensure_current_user, only: :update_password
      before_action :ensure_edit_permissions, only: :update_permissions
      before_action :ensure_subscription_limit, only: [:create, :new]

      def index
        # show users but remove admin users
        @vendor = current_vendor
        @users = @vendor.users.includes(:spree_roles).select{|user| !user.is_admin?}
      end

      def show
        @user = current_vendor.users.find(params[:id])
        @current_user = current_spree_user.id == @user.id
        render :show
      end

      def new
        @user = current_vendor.users.new
        render :new
      end

      def create
        @user = current_vendor.users.new(user_params)
        @user.spree_roles << Spree::Role.find_by_name('vendor')
        if @user.save
          flash[:success] = "User has been saved"
          redirect_to edit_manage_account_user_path(@user)
        else
          flash.now[:errors] = @user.errors.full_messages
          render :new
        end
      end

      def edit
        @user = current_vendor.users.find(params[:id])
        @custom =  @user.permissions.to_a != @user.permission_group.try(:permissions).to_a ? true : false
        if @custom
          @user.permission_group = nil
        end
        @current_user = current_spree_user.id == @user.id
        @all_permission_groups = existing_permission_groups(@user.company_id)
        @user_adjust = current_spree_user.permission_users_user_adjust
        render :edit
      end

      def update
        @user = current_vendor.users.find(params[:id])
        @all_permission_groups = existing_permission_groups(@user.company_id)
        if params.fetch(:user, {}).fetch(:permission_group, nil).present?
          @user.permissions.update(existing_permission_groups(@user.company_id).find(params[:user][:permission_group]).permissions)
          @user.permission_group = existing_permission_groups(@user.company_id).find(params[:user][:permission_group])
        end
        if @user.update(user_params)
          flash[:success] = "Profile updated"
          redirect_to edit_manage_account_user_path(@user)
        else
          @user_adjust = current_spree_user.permission_users_user_adjust
          flash[:errors] = @user.errors.full_messages
          render :edit
        end
      end

      def destroy
        @user = current_vendor.users.find(params[:id])
        @user.destroy!
        redirect_to edit_manage_account_user_path(@user)
      end

      def update_comm_settings
        @user = current_vendor.users.find(params[:id])
        if @user.update(comms_settings_params)
          flash[:success] = "Communication settings changed successfully"
          redirect_to edit_manage_account_user_url(anchor: 'comm_settings_tab')
        else
          flash[:error] = @user.errors.full_messages.join(', ')
          redirect_to edit_manage_account_user_url(anchor: 'comm_settings_tab')
        end
      end

      def update_password
        @user = current_vendor.users.find(params[:id])
        if @user.update_with_password(params.require(:user).permit(:password, :password_confirmation, :current_password))
          sign_in @user, :bypass => true
          flash[:success] = "Password changed"
          redirect_to edit_manage_account_user_url
        else
          flash[:error] = @user.errors.full_messages.join(', ')
          redirect_to edit_manage_account_user_url(anchor: 'change_password_tab')
        end
      end

      def update_permissions
        @user = current_vendor.users.find(params[:id])
        if permission_group_params[:permission_group_id].blank? && @user.update(permission_group_params)
          flash[:success] = "Permissions updated"
          redirect_to edit_manage_account_user_url(anchor: 'permissions_tab')
        elsif permission_group_params[:permission_group_id].present?
          group_id = permission_group_params[:permission_group_id]
          @user.update_columns(
            permission_group_id: group_id,
            permissions: @user.company.permission_groups.find_by_id(group_id).try(:permissions)
          )
          flash[:success] = "Permissions updated"
          redirect_to edit_manage_account_user_url(anchor: 'permissions_tab')
        else
          flash[:error] = @user.errors.full_messages.join(', ')
          redirect_to edit_manage_account_user_url(anchor: 'permissions_tab')
        end
      end

      def toggle_permissions
        @user = current_vendor.users.find(params[:id])
        @permission_group = current_vendor.permission_groups.find_by_id(params[:permission_group_id])
        @all_permission_groups = existing_permission_groups(@user.company_id)
        if @permission_group
          @permission_group.ensure_up_to_date
          @user.permissions = @permission_group.reload.permissions
          @user.permission_group_id = @permission_group.id
        else
          params[:permission_group_id] = true
        end
        # @permissions = {"None" => 0, "Read" => 1, "Write" => 2}
        # @boolean = {"Yes" => true, "No" => false}
        respond_with do |format|
          format.js {@user}
        end
      end

      def destroy
        @user = current_vendor.users.find(params[:id])
        if @user.destroy
          flash[:success] = 'User has been deleted'
        else
          flash[:error] = 'Could not delete user'
        end
        redirect_to manage_account_users_path
      end

      private

      def user_params
        params.require(:user).permit(:firstname, :lastname, :email, :phone, :position, :customer_admin, :view_images, :password, :password_confirmation).tap do |whitelisted|
          whitelisted[:view_images] = params[:user][:view_images]
        end
      end

      def comms_settings_params
        params.require(:user).permit(
          :order_confirmed,
          :order_approved,
          :order_revised,
          :order_received,
          :order_canceled,
          :order_review,
          :order_finalized,
          :daily_summary,
          :daily_shipping_reminder,
          :low_stock,
          :so_edited,
          :so_reminder,
          :stop_all_emails,
          :so_create_error,
          :discontinued_products,
          :summary_send_time)

      end

      def permission_group_params
        params.require(:user).permit(
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

      def ensure_read_permission
        return true if current_spree_user.id.to_s == params[:id]
        if current_spree_user.cannot_read?('basic_options', 'users')
          flash[:error] = 'You do not have permission to view users'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        return true if current_spree_user.id.to_s == params[:id]
        if current_spree_user.cannot_read?('basic_options', 'users')
          flash[:error] = 'You do not have permission to view users'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('basic_options', 'users')
          flash[:error] = 'You do not have permission to edit users'
          redirect_to manage_account_users_path
        end
      end

      def ensure_current_user
        unless current_spree_user.id.to_s == params[:id]
          flash[:error] = "You do not have permission to change that user's password"
          redirect_to manage_account_users_path
        end
      end

      def ensure_edit_permissions
        if !current_company.subscription_includes?('advanced_user_rights')
          flash[:error] = 'Your current subscription does not allow editing user permissions. Please contact Sweet to upgrade your plan.'
          redirect_to manage_account_users_path
        elsif !current_spree_user.permission_users_user_adjust
          flash[:error] = "You do not have permission to edit user's permissions"
          redirect_to manage_account_users_path
        end
      end

      def ensure_subscription_limit
         @vendor = current_vendor
         @users = @vendor.users.includes(:spree_roles).select{|user| !user.is_admin?}
         @user_limit = @vendor.subscription_limit('user_limit')
         unless @vendor.within_subscription_limit?('user_limit', @users.count)
           flash[:error] = "Your subscription is limited to #{@user_limit} #{'user'.pluralize(@user_limit)}. Please contact Sweet to add additional users."
           redirect_to manage_account_users_path
         end
      end

    end
  end
end
