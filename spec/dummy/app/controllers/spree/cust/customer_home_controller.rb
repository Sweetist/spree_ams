module Spree
 module Cust
  class CustomerHomeController < Spree::BaseController
    include Spree::Core::ControllerHelpers::Order

    layout 'frontend-customer'
    #
    # Leverage default devise authenticate_#{model_name}! method.
    # Instead of just redirecting, this:
    # 1. returns unauthenticated
    # 2. stores referer in stored_location_for(resource)
    # 3. redirects to default url
    # you can always do other "permissions" in next before_action hook.
    #
    before_action :authenticate_spree_user!
    before_action :authorize_customer
    before_action :ensure_vendor_account
    before_action do |controller|
      unless controller.class == Spree::Cust::UsersController
        ensure_user_has_accounts
      end
    end

    helper_method :current_customer, :order_can_add_products?, :order_is_void?,
                  :current_vendor, :current_vendor_view_settings,
                  :any_vendor_view_order_payments?, :any_vendor_view_invoice_payments?,
                  :current_vendor_variant_nest_name?, :current_company,
                  :has_multi_accounts?, :has_multi_vendors?,
                  :set_order_ship_address, :set_order_bill_address

    protected

    def action
      params[:action].to_sym
    end

    def authorize_customer
      if (request.host == ENV['DEFAULT_URL_HOST'])
        host_company = current_spree_user.try(:company)
      else
        host_company = Spree::Company.where(custom_domain: request.host).first
      end

      if current_spree_user.nil? || !current_spree_user.is_customer?
        flash[:error] = "You must be logged in" unless current_spree_user
        redirect_to root_url
      elsif current_spree_user.company == host_company
        @customers_vendor = host_company.vendors.first
      elsif current_spree_user.company.vendor_ids.include?(host_company.id)
        @customers_vendor = host_company
      else
        flash[:error] = "You do not have permission to view the page requested"
        sign_out(current_spree_user)
        redirect_to request_access_url
      end

    end

    def current_customer
      @customer ||= current_spree_user.company
    end

    def current_company
      current_spree_user.company
    end

    def can_select_delivery
      current_customer.can_select_delivery_from_some?
    end

    def any_vendor_view_order_payments?
      return @any_vendor_view_order_payments unless @any_vendor_view_order_payments.nil?
      @any_vendor_view_order_payments = current_customer.any_vendor_view_order_payments?
    end

    def any_vendor_view_invoice_payments?
      return @any_vendor_view_invoice_payments unless @any_vendor_view_invoice_payments.nil?
      @any_vendor_view_invoice_payments = current_customer.any_vendor_view_invoice_payments?
    end

    # vendor accounts represent accounts in which the user is the buyer
    def current_vendor_account
      if request.host == ENV['DEFAULT_URL_HOST']
        @current_vendor_account ||= current_spree_user.vendor_accounts.find_by_id(session[:vendor_account_id]) rescue nil
      else
        @current_vendor_account ||= current_spree_user.vendor_accounts
                                                      .joins(:vendor)
                                                      .where('spree_companies.custom_domain = ?', request.host)
                                                      .where('spree_accounts.id = ?', session[:vendor_account_id])
                                                      .first rescue nil
      end
    end

    def current_order
      if @order.present?
        return @order if @order.id.to_i == session[:order_id].to_i
      end

      @order = current_customer.purchase_orders.find_by_id(session[:order_id]) rescue nil
      @current_order = @order
    end

    def current_vendor
      @vendor ||= if request.host != ENV['DEFAULT_URL_HOST']
        current_customer.vendors.find_by_custom_domain(request.host) rescue nil
      else
        current_customer.vendors.find_by_id(session[:vendor_id]) rescue nil
      end
    end

    def current_vendor_view_settings
      @current_vendor_view_settings ||= current_vendor.try(:customer_viewable_attribute)
    end

    def current_vendor_variant_nest_name?
      return @current_vendor_variant_nest_name unless @current_vendor_variant_nest_name.nil?
      @current_vendor_variant_nest_name = current_vendor.try(:cva).try(:variant_nest_name)
    end

    def current_currency
      current_vendor.try(:currency) || current_customer.vendors.first.try(:currency) || Spree::Config[:currency]
    end

    def set_order_session(order = nil)
      if params[:order_id]
        order ||= current_customer.purchase_orders.friendly.find(params[:order_id]) rescue nil
      else
        order ||= current_customer.purchase_orders.friendly.find(params[:id]) rescue nil
      end
      session[:order_id] = order.try(:id)
      session[:vendor_id] = order.try(:vendor_id)
      session[:vendor_account_id] = order.try(:account_id)
      order
    end

    def associate_user(order)
      unless current_spree_user.is_admin?
        order.user_id = current_spree_user.id
        order.created_by_id = current_spree_user.id
      end

      order.set_email
      order.ship_address_id = order.account.try(:default_ship_address_id)
      order.bill_address_id = order.account.try(:bill_address_id)
      order.created_by_id = current_spree_user.id
    end

    def clear_current_order
      session[:order_id] = nil
    end
    def clear_current_vendor_account
      session[:vendor_id] = nil
      session[:vendor_account_id] = nil
    end

    def order_has_shipped?
        return false unless current_order
        current_order.has_shipped?
    end

    def order_can_add_products?
      return @can_add unless @can_add.nil?
      @order ||= current_order
      return false unless @order && @order.delivery_date >= DateHelper.sweet_today(@order.vendor.try(:time_zone))
      @can_add ||= States[@order.state].between?(States['cart'], States['approved']) && @order.is_submitable?
    end

    def order_is_void?
      @order ||= current_order
      return false unless @order
      @is_void ||= @order.state == 'void' rescue nil
    end

    def flash_message_for(object, event_sym)
      resource_desc  = object.class.model_name.human
      resource_desc += " \"#{object.name}\"" if object.respond_to?(:name) && object.name.present?
      Spree.t(event_sym, resource: resource_desc)
    end

    def ensure_vendor_account
      if session[:vendor_account_id] && current_spree_user.vendor_accounts.where(id: session[:vendor_account_id]).first.nil?
        clear_current_order
        clear_current_vendor_account
      end
    end

    def existing_permission_groups(id)
      return Spree::PermissionGroup.where(company_id: [id, nil])
    end

    def ensure_user_has_accounts
      if request.host == ENV['DEFAULT_URL_HOST']
        if current_spree_user.vendor_accounts.empty?
          flash[:error] = "You don't have access to any accounts yet"
          redirect_to edit_my_profile_path(anchor: "account_access")
        end
      else
        if current_spree_user.vendors.where(custom_domain: request.host).empty?
          flash[:error] = "You don't have access to any accounts yet"
          redirect_to edit_my_profile_path(anchor: "account_access")
        end
      end
    end

    def current_user_vendor_accounts
      current_spree_user.vendor_accounts
    end

    def has_multi_accounts?
      current_user_vendor_accounts.count > 1
    end

    def has_multi_vendors?
      current_spree_user.vendors.distinct.count > 1
    end

    def set_order_ship_address
      if @order.try(:ship_address)
        @order.ship_address
      elsif @account.try(:default_ship_address)
        @account.default_ship_address
      else
        @account.ship_addresses.new(account_id: @account.id, addr_type: 'shipping')
      end
    end

    def set_order_bill_address
      if @order.try(:bill_address)
        @order.bill_address
      elsif @account.try(:bill_address)
        @account.bill_address
      else
        @account.build_bill_address(account_id: @account.id, addr_type: 'billing')
      end
    end
  end
 end
end
