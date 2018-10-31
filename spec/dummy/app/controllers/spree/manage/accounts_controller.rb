module Spree
  module Manage

    class AccountsController < Spree::Manage::BaseController
      respond_to :js

      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :clear_current_order
      before_action :clear_current_account
      before_action :ensure_read_permission, only: [:show, :index]
      before_action :ensure_write_permission, only: [:new, :edit, :create, :update, :destroy, :activate, :deactivate]
      before_action :ensure_subscription_limit, only: [:new, :create, :activate]

      def index
        @vendor = current_vendor
        params[:q] = nil if params[:commit] == 'reset'
        params[:q] ||= {}
        params[:commit] = nil

        format_ransack_date_field(:last_invoice_date_gteq, @vendor)
        format_ransack_date_field(:last_invoice_date_lteq, @vendor)

        case params[:active]
        when 'both'
          @search = @vendor.customer_accounts.ransack(params[:q])
        when 'inactive'
          @search = @vendor.customer_accounts.inactive.ransack(params[:q])
        else
          @search = @vendor.customer_accounts.active.ransack(params[:q])
        end

        @search.sorts = 'fully_qualified_name ASC' if @search.sorts.empty?

        revert_ransack_date_to_view(:last_invoice_date_gteq, @vendor)
        revert_ransack_date_to_view(:last_invoice_date_lteq, @vendor)

        @accounts = @search.result.includes(:payment_terms, :orders, :contacts, :shipping_addresses, :customer).page(params[:page])
        respond_with(:manage, @accounts)
      end

      def new
        @vendor = current_vendor
        @account = @vendor.customer_accounts.new
        @ship_address = Spree::Address.new
        @bill_address = Spree::Address.new
        @new_form = true
        render :new
      end

      def create
        @vendor = current_vendor
        @account = @vendor.customer_accounts.new(account_params)
        if @account.parent_id.blank?
          @company = @account.build_customer(
            name: account_params.fetch(:name,''),
            time_zone: @vendor.time_zone
          )
        else
          customer_account = @vendor.customer_accounts.find_by_id(@account.parent_id)
          @company = @vendor.customers.find_by_id(customer_account.try(:customer_id))
        end
        @company.try(:save)
        @account.customer_id = @company.try(:id)
        if @account.save
          @account.update_columns(bill_address_id: @account.billing_addresses.first)
          session[:account_id] = @account.try(:id)
          flash[:success] = "A new account has been created!"
          redirect_to edit_manage_customer_account_path(@company, @account)
        else
          @company.destroy! if @company && @company.vendor_accounts.count == 0
          errors = @company.try(:errors).try(:full_messages) + @account.errors.full_messages
          flash.now[:errors] = errors.uniq
          render :new
        end
      end

      def show
        redirect_to edit_manage_customer_account_path
      end

      def edit
        params[:promotion] ||= {}
        @vendor = current_vendor
        @account = current_vendor.customer_accounts.find(params[:id])
        @contacts = @account.contacts
        @contact = current_vendor.contacts.new
        @contact_account_ids = @contact.account_ids
        @customer_accounts = current_vendor.customer_accounts
        @payment_method = Spree::PaymentMethod.where(vendor_id: @vendor.id)
        set_address
        @account.build_note unless @account.note
        @promotions = []
        @new_form = false
        build_report_data
        session[:account_id] = @account.try(:id)
        # commontator_thread_show(@account) #uncomment to show expanded on page load
        render :edit
      end

      def update
        @vendor = current_vendor
        @account = current_vendor.customer_accounts.find(params[:id])
        @contacts = @account.contacts
        @customer = Spree::Company.find(@account.customer_id)
        session[:account_id] = @account.id
        @promotions = promotions

        set_address
        if @account.update(account_params)
          unless @account.inactive_reason.blank? || @account.inactive_date.present?
            if @account.deactivate!
              flash[:success] = "Account has been deactivated!"
              redirect_to manage_customer_account_path(@customer, @account)
            else
              @contact = current_vendor.contacts.new
              @contact_account_ids = @contact.account_ids
              flash.now[:errors] = @account.errors.full_messages
              build_report_data
              render :edit
            end
          else
            flash[:success] = "Account has been updated!"
            redirect_to edit_manage_customer_account_path(@customer, @account)
          end
        else
          # in case a new contact needs to be made
          @contact = current_vendor.contacts.new
          @contact_account_ids = @contact.account_ids
          @customer_accounts = current_vendor.customer_accounts

          @new_form = false
          build_report_data
          flash.now[:errors] = @account.errors.full_messages
          render :edit
        end
      end

      def update_default_address
        @account = current_vendor.customer_accounts.find_by_id(params[:id])
        @customer = @account.customer
        @address = @account.ship_addresses.find_by_id(params[:address_id])

        @account.set_default_ship_address(@address.id) if @address

        if @account.save
          set_address
          respond_to do |format|
            format.js do
              flash[:success] = 'Default address successfully saved.'
            end
          end
        else
          respond_to do |format|
            format.js do
              flash.now[:errors] = @account.errors.full_messages
            end
          end
        end
      end

      def update_primary_contact
        @account = current_vendor.customer_accounts.find_by_id(params[:id])
        @account.primary_cust_contact_id = params[:contact_id]
        unless @account.save
          flash.now[:errors] = @account.errors.full_messages
        end
        @contacts = @account.contacts
        respond_to do |format|
          format.js {}
        end
      end

      def create_new_contact
        params[:contact] ||= {}
        account_ids = params[:contact][:account_ids]
        @account = current_vendor.customer_accounts.find_by_id(params[:id])
        @contact = current_vendor.contacts.new(contact_params)
        @customer_accounts = current_vendor.customer_accounts
        selected_customer_accounts = @customer_accounts.where(id: account_ids)

        if selected_customer_accounts.pluck(:customer_id).uniq.count <= 1
          if @contact.save
            @contact.account_ids = account_ids

            # go through customer accounts, and, if this is the first contact for any of them,
            # set this contact as the primary contact on them
            selected_customer_accounts.each do |customer|
              if customer.contacts.count == 1
                customer.primary_cust_contact_id = @contact.id
                customer.save
              end
            end
            @account.reload

            respond_with do |format|
              format.js do
                # setting up @contacts for create customer call from customer page
                @contacts = @account.contacts
                flash.now[:success] = 'Contact was successfully created.'
              end
            end
          else
            respond_with do |format|
              format.js do
                flash.now[:errors] = @contact.errors.full_messages
                @contacts = @account.contacts
              end
            end
          end
        else
          respond_with do |format|
            format.js do
              flash.now[:errors] = ["A contact cannot be linked to non-related accounts. Please contact help@getsweet.com if you have any questions."]
              @contacts = @account.contacts
              render :new
            end
          end
        end
      end

      def delete_contact

        @account = current_vendor.customer_accounts.find_by_id(params[:id])
        @contact = current_vendor.contacts.find_by_id(params[:contact_id])

        # replace or remove account primary contact_id if contact being deleted is primary contact
        @account.replace_or_remove_primary_contact(@contact.id)

        if @contact.destroy
          respond_with do |format|
            format.js do
              @contacts = @account.contacts
              flash[:success]='Contact was deleted.'
            end
          end
        else
          respond_with do |format|
            format.js do
              #redirect_to :back
              @contacts = @account.contacts
              flash.now[:errors] = @contact.errors.full_messages
            end
          end
        end
      end

      def activate
        @vendor = current_vendor
        @account = current_vendor.customer_accounts.find(params[:id])
        @account.activate!

        flash[:success] = 'Account activated'

        redirect_to manage_customer_account_path(@account.customer, @account)
      end

      def deactivate
        @vendor = current_vendor
        @account = current_vendor.customer_accounts.find(params[:id])

        respond_to do |format|
          format.js {}
        end
      end

      def promotions
        params[:promotion] ||= {}
        params[:promotion][:name] ||= ''
        @vendor = current_vendor
        @account = @vendor.customer_accounts.find(params[:id])

        if params[:promotion][:product_id].present?
          @promotions = current_vendor.promotions
          .where(id: @account.promotion_ids)
          .where(id: @vendor.products.find(params[:promotion][:product_id]).promotion_ids)
          .where('spree_promotions.name ILIKE ?', "%#{params[:promotion][:name]}%")
          .includes(:promotion_actions, :promotion_rules)
        else
          @promotions = current_vendor.promotions
          .where(id: @account.promotion_ids)
          .where('spree_promotions.name ILIKE ?', "%#{params[:promotion][:name]}%")
          .includes(:promotion_actions, :promotion_rules)
        end

        respond_to do |format|
          format.js {@promotions}
          format.html {@promotions}
        end
      end

      private

      def account_params
        params.require(:account).permit(
        :number, :payment_terms_id,
        :customer_id, :name, :display_name, :inactive_reason, :email, :default_txn_class_id,
        :balance, :default_shipping_method_id, :rep_id, :customer_type_id, :action,
        :shipping_group_id, :parent_id, :tax_exempt_id, :taxable, :credit_limit,
        :default_stock_location_id,
        :default_shipping_method_only,
        :delivery_on_monday,
        :delivery_on_tuesday,
        :delivery_on_wednesday,
        :delivery_on_thursday,
        :delivery_on_friday,
        :delivery_on_saturday,
        :delivery_on_sunday,
        :send_mail,
        :shipment_email,
        :tax_category_id,
        :default_ship_address_id,
        billing_addresses_attributes:
          [ :id, :firstname, :lastname, :company, :phone,
            :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id, :addr_type
          ],
        shipping_addresses_attributes:
          [ :id, :name, :firstname, :lastname, :company, :phone,
            :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id, :addr_type
          ],
          note_attributes: [:id, :body],
        payment_method_ids: []
        )
      end

      def contact_params
        params.require(:contact).permit(:contact, :first_name, :last_name, :email, :phone, :position, :notes, :company_id)
      end

      def deactivate_params
        params.require(:account).permit(:inactive_reason)
      end

      def set_address
        # country_id = current_vendor.try(:bill_address).try(:country_id) || Spree::Address.default.country_id # rather set US as default in form

        @account = current_vendor.customer_accounts.find_by_id(params[:id])
        @bill_address = @account.bill_address.present? ? @account.bill_address : @customer.build_bill_address
        @ship_addresses = @account.shipping_addresses - [@account.default_ship_address]

        if @account.default_ship_address
          @selected_ship_address = @account.default_ship_address
        elsif Spree::Address.where(account_id: @account.id, addr_type: 'shipping').first.present?
          @selected_ship_address = Spree::Address.where(account_id: @account.id, addr_type: 'shipping').first
          @account.update_columns(default_ship_address_id: @selected_ship_address.id)
        else
          @selected_ship_address = @customer.build_ship_address
        end
      end

      def ensure_vendor
        @customer = Spree::Company.find(params[:customer_id])
        unless @customer.vendors.include?(current_vendor)
          flash[:error] = "You do not have permission to view the page requested"
          redirect_to root_url
        end
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('basic_options', 'customers')
          flash[:error] = 'You do not have permission to view customer accounts'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('basic_options', 'customers')
          flash[:error] = 'You do not have permission to view customer accounts'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('basic_options', 'customers')
          flash[:error] = "You do not have permission to edit customer accounts"
          redirect_to manage_accounts_path
        end
      end

      def ensure_subscription_limit
        limit = current_company.subscription_limit('relationships')
        unless current_company.within_subscription_limit?(
            'relationships',
            current_company.all_accounts.active.count
          )
          flash[:error] = "Your subscription is limited to #{limit} #{'relationship'.pluralize(limit)}"
          redirect_to manage_accounts_path
        end
      end

      def build_report_data
        @product_show_count = params[:product_show_count] ? params[:product_show_count].to_i : 10 #10 is just a number we decided on to show, no special value
        end_date = Time.current
        start_date = end_date - 30.days
        currency = CurrencyHelper.currency_symbol(current_vendor.currency)
        orders = @account.orders.order('delivery_date DESC') # must be ordered by date to work in time series charts
        approved_orders = @account.orders
                          .approved.where('delivery_date BETWEEN ? AND ?', start_date, end_date)
                          .order('delivery_date DESC') # must be ordered by date to work in time series charts
        @search = orders.ransack(params[:q])
        @orders = @search.result.page(params[:page])

        if @account.sub_accounts.present?
          ids = [@account.id] + @account.sub_accounts.ids
          orders_sa = Spree::Order.where(account_id: ids).order('delivery_date DESC')
          approved_orders_sa =  Spree::Order.where(account_id: ids)
                                            .approved
                                            .where('delivery_date BETWEEN ? AND ?', start_date, end_date)
                                            .order('delivery_date DESC') # must be ordered by date to work in time series charts
          totals_sa = Hash.new(0)
          approved_orders_sa.each do |order|
            totals_sa[order.delivery_date] += order.total
          end
          order_totals_data_sa = []
          totals_sa.each do |date, total|
            order_totals_data_sa << [date.to_i*1000, total.to_i]
          end
          @search_sa = orders_sa.ransack(params[:q])
          @orders_sa = @search_sa.result.page(params[:page])
          @sales_history_chart_data_sa = ReportHelper.build_areaspline_chart(order_totals_data_sa, '30 Day Sales',"Total Sales (#{@vendor.currency})" )

          sql_arr = [
            Spree::Product.products_query({
              delivery_date_gteq: true,
              delivery_date_lteq: true,
              account_id: true
            }),
            @vendor.id, ApprovedStates, start_date, end_date, ids
          ]
          @line_items_sa = Spree::LineItem.find_by_sql(sql_arr)
          revenue = Hash.new(0)
          @line_items_sa.each do |li_group|
            revenue[li_group.default_display_name] = li_group.revenue
          end
          @revenue_chart_data_sa = ReportHelper.build_bar_chart(ReportHelper.sorted_data(revenue, @product_show_count), "Sales (#{currency})", "Product Revenue", "Total Sales (#{currency})")
        end

        totals = Hash.new(0)
        approved_orders.each do |order|
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

        @line_items = Spree::LineItem.find_by_sql(sql_arr)

        # @line_items = Spree::LineItem.find_by_sql([Spree::Product.products_by_customer_query, @vendor.id, @account.id, start_date, end_date])
        revenue = Hash.new(0)
        @line_items.each do |li_group|
          revenue[li_group.default_display_name] = li_group.revenue
        end

        @sales_history_chart_data = ReportHelper.build_areaspline_chart(order_totals_data, '30 Day Sales',"Total Sales (#{@vendor.currency})" )
        @revenue_chart_data = ReportHelper.build_bar_chart(ReportHelper.sorted_data(revenue, @product_show_count), "Sales (#{currency})", "Product Revenue", "Total Sales (#{currency})")
      end

    end
  end
end
