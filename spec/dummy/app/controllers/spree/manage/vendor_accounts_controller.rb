module Spree
  module Manage

    class VendorAccountsController < Spree::Manage::BaseController
      respond_to :js

      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :clear_current_order
      before_action :clear_current_account
      before_action :ensure_read_permission, only: [:show, :index]
      before_action :ensure_write_permission, only: [:new, :edit, :create, :update, :destroy, :activate, :deactivate]
      before_action :ensure_subscription_limit, only: [:new, :create]

      def index
        @company = current_company
        params[:q] = nil if params[:commit] == 'reset'
        params[:q] ||= {}
        params[:commit] = nil


        case params[:active]
        when 'both'
          @search = @company.vendor_accounts.ransack(params[:q])
        when 'inactive'
          @search = @company.vendor_accounts.inactive.ransack(params[:q])
        else
          @search = @company.vendor_accounts.active.ransack(params[:q])
        end

        @accounts = @search.result.includes(:payment_terms, :orders, :users, :shipping_addresses, :customer).order('fully_qualified_name ASC').page(params[:page])
        respond_with(:manage, @accounts)
      end


      def new
        @company = current_company
        @account = @company.vendor_accounts.new
        #@ship_address = Spree::Address.new
        @bill_address = Spree::Address.new
        @bill_address.country_id = current_company.bill_address.try(:country_id)
        @new_form = true
        render :new
      end

      def create
        @company = current_company
        @account = @company.vendor_accounts.new(account_params)

        # as of Feb 2017, we've not set up the ability to select existing companies on Sweet as vendors
        # so the if statement below will default to the "blank" conditional
        if @account.vendor.blank?
          @new_vendor = @account.build_vendor(
            name: account_params.fetch(:name,''),
            time_zone: @company.time_zone
          )
          @new_vendor.currency = @company.currency
          @new_vendor.receive_orders = true
          @new_vendor.save
          @account.vendor_id = @new_vendor.id
        else
          @existing_vendor = Spree::Company.find_by_id(account_params[:vendor_id])
          if @existing_vendor.nil?
            flash.now[:errors] = "Could not find company"
            render :new and return
          end

          # once we build ability to link up existing companies on Sweet as vendors,
          # we want to check if company user has selected or entered an existing vendor
          # then we can set up the association as below
            # find company by name or allow user to select (?)
            # associate company as the vendor on this account
            # inform company that they've been added as a vendor
            # (do we need some kind of confirmation from the vendor that they accept?)
        end

        # @account.vendor_id = @new_vendor.try(:id)
        if (@new_vendor.try(:persisted?) || @existing_vendor.try(:persisted?)) && @account.save
          @account.create_default_stock_location unless @existing_vendor
          session[:account_id] = @account.try(:id)
          flash[:success] = "A new vendor account has been created!"
          redirect_to manage_vendor_vendor_account_path(@new_vendor, @account)
        else
          @bill_address = @account.bill_address
          @bill_address ||= Spree::Address.new(country_id: current_company.billing_address.try(:country_id))
          errors = @new_vendor.try(:errors).try(:full_messages) + @account.errors.full_messages
          @new_vendor.try(:destroy!)
          flash.now[:errors] = errors.uniq
          render :new
        end
      end

      def show
        params[:promotion] ||= {}
        @company = current_company
        @account = current_company.vendor_accounts.find(params[:id])
        @vendor = @account.vendor

        @product_show_count = params[:product_show_count] ? params[:product_show_count].to_i : 10 #10 is just a number we decided on to show, no special value
        end_date = Time.current
        start_date = end_date - 30.days

        @all_orders = @account.orders
        @orders = @all_orders
          .approved
          .where('delivery_date BETWEEN ? AND ?', start_date, end_date)
          .order('delivery_date ASC') # must be ordered by date to work in time series charts

        totals = Hash.new(0)
        @orders.each do |order|
          totals[order.delivery_date] += order.total
        end

        order_totals_data = []
        totals.sort_by {|date, total| date}.each do |date, total|
          order_totals_data << [date.to_i*1000, total.to_i]
        end

        sql_arr = [
          Spree::Product.products_query({
            delivery_date_gteq: true,
            delivery_date_lteq: true,
            account_id: true
          }),
          @vendor.id, ApprovedStates, start_date, end_date, [@account.id]
        ]

        # @line_items = Spree::LineItem.find_by_sql([Spree::Product.products_by_customer_query, @company.id, @account.id, start_date, end_date]) ///////// OLD
        @line_items = Spree::LineItem.find_by_sql(sql_arr)
        revenue = Hash.new(0)
        @line_items.each do |li_group|
          revenue[li_group.name] = li_group.revenue
        end

        currency = CurrencyHelper.currency_symbol(current_company.currency)
        @sales_history_chart_data = ReportHelper.build_areaspline_chart(order_totals_data, '30 Day Spend',"Total Spend (#{currency})" )
        @revenue_chart_data = ReportHelper.build_bar_chart(ReportHelper.sorted_data(revenue, @product_show_count), "Spend (#{currency})", "Spend by Product", "Total Spend (#{currency})")

        @bill_address = @account.bill_address || @account.billing_addresses.last

        @all_orders = @all_orders.ransack(params[:q]).result.page(params[:page])

        session[:vendor_id] = @account.vendor_id
        render :show
      end

      def edit
        params[:promotion] ||= {}
        @company = current_company
        @account = current_company.vendor_accounts.find(params[:id])
        @vendor = @account.vendor

        @bill_address = @account.bill_address
        @bill_address ||= @account.billing_addresses.last
        @bill_address ||= @account.build_bill_address(
          country_id: @company.try(:bill_address).try(:country_id) || Spree::Address.default.country_id
        )
        @account.build_note unless @account.note
        @new_form = false
        session[:account_id] = @account.try(:id)
        # commontator_thread_show(@account) #uncomment to show expanded on page load
        render :edit
      end

      def update
        @company = current_company
        @account = current_company.vendor_accounts.find(params[:id])
        @vendor = @account.vendor
        session[:account_id] = @account.id
        if @account.update(account_params)
          unless @account.inactive_reason.blank? || @account.inactive_date.present?
            if @account.deactivate!
              flash[:success] = "Account has been deactivated!"
              redirect_to edit_manage_vendor_vendor_account_path(@vendor, @account)
            else
              flash.now[:errors] = @account.errors.full_messages
              render :edit
            end
          else
            @bill_address = @account.bill_address
            @bill_address ||= @account.billing_addresses.last
            @bill_address ||= @account.build_bill_address(
              country_id: @company.try(:bill_address).try(:country_id) || Spree::Address.default.country_id
            )
            flash[:success] = "Account has been updated!"
            redirect_to manage_vendor_vendor_account_path(@vendor, @account)
          end
        else
          flash.now[:errors] = @account.errors.full_messages
          render :edit
        end
      end

      def activate
        @company = current_company
        @account = current_company.vendor_accounts.find(params[:id])
        @vendor = @account.vendor
        @account.activate!

        flash[:success] = 'Account activated'

        redirect_to edit_manage_vendor_vendor_account_path(@account.vendor, @account)
      end

      def deactivate
        @company = current_company
        @account = current_company.vendor_accounts.find(params[:id])
        @vendor = @account.vendor

        respond_to do |format|
          format.js {}
        end
      end

      private

      def account_params
        params.require(:account).permit(
        :number, :payment_terms_id, :customer_id, :name, :inactive_reason, :email,
        :balance, :default_shipping_method_id, :rep_id, :customer_type_id, :action,
        :shipping_group_id, :parent_id, :tax_exempt_id, :send_purchase_orders_emails,
        :delivery_on_monday,
        :delivery_on_tuesday,
        :delivery_on_wednesday,
        :delivery_on_thursday,
        :delivery_on_friday,
        :delivery_on_saturday,
        :delivery_on_sunday,
        billing_addresses_attributes:
          [ :id, :firstname, :lastname, :phone, :company,
            :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id, :addr_type
          ],
        shipping_addresses_attributes:
          [ :id, :firstname, :lastname, :phone, :company,
            :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id, :addr_type
          ],
          note_attributes: [:id, :body]
        )
      end

      def user_params
        params.require(:user).permit(:user, :firstname, :lastname, :email, :phone, :position, :is_admin, :view_images, :password, :password_confirmation)
      end

      def deactivate_params
        params.require(:account).permit(:inactive_reason)
      end

      def ensure_vendor
        @supplier = Spree::Account.find(params[:id])
        return if @supplier.customer_id == current_spree_user.company_id

        flash[:error] = 'You do not have permission to view the page requested'
        redirect_to manage_path
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('vendors', 'purchase_orders')
          flash[:error] = 'You do not have permission to view vendors'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('vendors', 'purchase_orders')
          flash[:error] = 'You do not have permission to view vendor accounts'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('vendors', 'purchase_orders')
          flash[:error] = "You do not have permission to edit vendor accounts"
          redirect_to manage_vendor_accounts_path
        end
      end

      def ensure_subscription_limit
        limit = current_company.subscription_limit('relationships')
        unless current_company.within_subscription_limit?(
            'relationships',
            current_company.all_accounts.active.count
          )
          flash[:error] = "Your subscription is limited to #{limit} #{'relationship'.pluralize(limit)}"
          redirect_to manage_vendor_accounts_path
        end
      end
    end
  end
end
