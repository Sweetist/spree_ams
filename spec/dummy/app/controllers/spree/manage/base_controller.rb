module Spree
  module Manage
    class BaseController < Spree::BaseController
      include Spree::Core::ControllerHelpers::Order
      layout 'frontend-vendor'
      helper 'spree/manage/navigation'
      helper 'spree/manage/tables'

      #before_action :authorize_admin
      #
      # Leverage default devise authenticate_#{model_name}! method.
      # Instead of just redirecting, this:
      # 1. returns unauthenticated
      # 2. stores referer in stored_location_for(resource)
      # you can always do other "permissions" in next before_action hook.
      #
      before_action :authenticate_spree_user!
      before_action :authorize_vendor
      before_action :ensure_customer_accounts

      helper_method :order_can_add_products?, :order_is_void?, :current_vendor,
                    :current_vendor_view_settings, :order_is_editable?,
                    :current_company, :current_vendor_variant_nest_name?

      protected
        def action
          params[:action].to_sym
        end

        def authorize_admin
          if respond_to?(:model_class, true) && model_class
            record = model_class
          else
            record = controller_name.to_sym
          end
          authorize! :admin, record
          authorize! action, record
         end

        def current_vendor
          return @vendor if @vendor
          return nil if current_spree_user.nil? || !current_spree_user.has_spree_role?('vendor')
          @vendor = current_spree_user.company
        end

        def current_company
          return @company if @company
          return nil if current_spree_user.nil? || !current_spree_user.has_spree_role?('vendor')
          @company = current_spree_user.company
        end

        def current_vendor_view_settings
          @current_vendor_view_settings ||= current_vendor.try(:customer_viewable_attribute)
        end

        def current_vendor_variant_nest_name?
          return @current_vendor_variant_nest_name unless @current_vendor_variant_nest_name.nil?
          @current_vendor_variant_nest_name = current_vendor.try(:cva).try(:variant_nest_name)
        end

        def current_currency
          current_company.try(:currency) || Spree::Config[:currency]
        end

        def authorize_vendor
          if (request.host == ENV['DEFAULT_URL_HOST'])
            host_company = current_spree_user.try(:company)
          else
            host_company = Spree::Company.where(custom_domain: request.host).first
          end
          if current_spree_user.nil?
            flash[:error] = "You must be logged in"
            redirect_to root_url
          elsif current_spree_user.company.vendor_ids.include?(host_company.try(:id)) && current_spree_user.is_customer?
            redirect_to orders_path
          elsif current_spree_user.company != host_company
            flash[:error] = "You do not have permission to view the page requested"
            sign_out(current_spree_user)
            redirect_to request_access_url
          elsif !current_spree_user.is_vendor?
            if current_spree_user.is_customer? && request.url.include?('manage/orders')
              url = request.url
              url.slice! "manage/"
              redirect_to url and return
            end
            flash[:error] = "You do not have permission to view the page requested"
            sign_out(current_spree_user)
            redirect_to root_url
          end
        end

        def set_order_session(order = nil)
          order ||= current_company.sales_orders.friendly.find(params[:id]) rescue nil
          session[:order_id] = order.try(:id)
          session[:account_id] = order.try(:account_id)
          order
        end

        def set_purchase_order_session(order = nil)
          order ||= current_company.purchase_orders.friendly.find(params[:id]) rescue nil
          session[:purchase_order_id] = order.try(:id)
          session[:account_id] = order.try(:account_id)
          order
        end

        def current_order
          if controller_name == "purchase_orders"
            current_company.purchase_orders.friendly.find(params[:id]) rescue nil
          else
            current_company.sales_orders.find_by_id(session[:order_id]) rescue nil
          end
        end

        def current_account
          current_company.customer_accounts.find_by_id(session[:account_id]) rescue nil
        end

        def clear_current_order
          session[:account_id] = nil
          session[:order_id] = nil
        end

        def order_has_shipped?
          return false unless current_order
          current_order.has_shipped?
        end

        def order_can_add_products?
          @order ||= current_order
          return false unless @order
          @can_add ||= States[@order.state].between?(States['cart'], (current_company.try(:last_editable_order_state) || States['approved'])) rescue nil
        end

        def order_is_void?
          @order ||= current_order
          return false unless @order
          @is_void ||= @order.state == 'void' rescue nil
        end

        def order_is_editable?
          @order ||= current_order
          return false unless @order
          @order.is_editable? && !order_is_void?
        end

        def clear_current_account
          session[:account_id] = nil
          session[:account_show_all] = nil
          params[:account_id] = nil
          params[:account_show_all] = nil
        end

        def associate_user(order)
          # order.user_id ||= order.account.customer.users.any? ? order.account.customer.users.first.id : current_spree_user.id
          order.set_email
          order.ship_address_id = order.account.try(:default_ship_address_id)
          order.bill_address_id = order.account.try(:bill_address_id)
          order.created_by_id = current_spree_user.id
        end

        def flash_message_for(object, event_sym)
          resource_desc  = object.class.model_name.human
          resource_desc += " \"#{object.name}\"" if object.respond_to?(:name) && object.name.present?
          Spree.t(event_sym, resource: resource_desc)
        end

        def user_list(account_id)
          return Spree::UserAccount.where(account_id: account_id)
        end

        def existing_permission_groups(id)
          return Spree::PermissionGroup.where(company_id: [id, nil])
        end

        def ensure_customer_accounts
          if session[:account_id] && current_company.customer_accounts.where(id: session[:account_id]).first.nil?
            clear_current_order
            clear_current_account
          end
        end

      end
   end
end
