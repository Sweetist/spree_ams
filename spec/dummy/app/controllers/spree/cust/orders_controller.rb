module Spree
 module Cust
  class OrdersController < Spree::Cust::CustomerHomeController
    include Spree::OrderDates
    respond_to :js

    helper_method :sort_column, :sort_direction, :get_delivery_date
    skip_before_action :verify_authenticity_token
    before_action :clear_current_vendor_account, only: [:new, :index]
    before_action :clear_current_order, only: [:new, :index]
    before_action :ensure_customer, only: [:show, :edit, :update, :destroy]
    before_action :ensure_order_in_time, only: [:destroy]
    before_action :ensure_can_resubmit, only: [:update]
    before_action :ensure_valid_address, only: [:update]

    rescue_from Spree::Core::GatewayError, with: :rescue_from_spree_gateway_error
    def index
      params[:q] ||= {}
      @customer = current_customer
      @vendors = @customer.vendors.order('name ASC')
      @vendor = current_vendor || @vendors.first
      @current_vendor_id = @vendor.try(:id)
      @days_available = generate_days(current_customer.vendor_accounts.first)
      @default_statuses = %w{cart complete approved shipped review invoice}
      params[:q][:vendor_id_eq] = @current_vendor_id unless request.host == ENV['DEFAULT_URL_HOST']
      params[:q][:shipment_state_or_state_cont_any] = @default_statuses if params[:q][:shipment_state_or_state_cont_any].blank?

      if params.fetch(:q).fetch(:payment_state_in, []).include?('paid')
        params[:q][:payment_state_in] << 'pending'
      end

      format_ransack_date_field(:delivery_date_gteq, @customer)
      format_ransack_date_field(:delivery_date_lteq, @customer)
      format_ransack_date_field(:invoice_date_gteq, @customer)
      format_ransack_date_field(:invoice_date_lteq, @customer)
      format_ransack_date_field(:completed_at_gteq, @customer)
      format_ransack_date_field(:completed_at_lteq, @customer)

      @search = @customer.purchase_orders
                         .where(account_id: current_spree_user.account_ids)

      if params[:q][:payment_state_in]
        @payment_states = params[:q][:payment_state_in].map do |state|
          state == 'none' ? nil : state
        end
        params[:q].delete(:payment_state_in)
        @search = @search.where(payment_state: @payment_states)
      end

      if params[:q] && params[:q][:shipment_state_or_state_cont_any].include?('cart')
        params[:q][:created_at_lteq], params[:q][:created_at_gteq] = params[:q][:completed_at_lteq], params[:q][:completed_at_gteq]
        params[:q][:completed_at_lteq], params[:q][:completed_at_gteq] = nil, nil
        @search = @search.order('created_at DESC')
                         .ransack(params[:q])
        @orders = @search.result
                         .includes(:vendor, account: :customer, thread: [comments: :creator])
                         .page(params[:page])
        params[:q][:completed_at_lteq], params[:q][:completed_at_gteq] = params[:q][:created_at_lteq], params[:q][:created_at_gteq]
        params[:q][:created_at_lteq], params[:q][:created_at_gteq] = nil, nil
      else
        @search = @search.order('created_at DESC')
                         .ransack(params[:q])
        @orders = @search.result
                         .includes(:account, :vendor, thread: [comments: :creator])
                         .page(params[:page])
      end

      params[:q][:payment_state_in] = @payment_states if @payment_states

      revert_ransack_date_to_view(:delivery_date_gteq, @customer)
      revert_ransack_date_to_view(:delivery_date_lteq, @customer)
      revert_ransack_date_to_view(:invoice_date_gteq, @customer)
      revert_ransack_date_to_view(:invoice_date_lteq, @customer)
      revert_ransack_date_to_view(:completed_at_gteq, @customer)
      revert_ransack_date_to_view(:completed_at_lteq, @customer)

      respond_with(@orders)
    end

    def show
      redirect_to edit_order_path(params[:id])
    end

    def new
      @customer = current_customer
      @order = @customer.purchase_orders.new(
        channel: Spree::Company::B2B_PORTAL_CHANNEL
      )
      @order.delivery_date = @order.next_available_delivery_date(@customer.time_zone)
      load_user_accounts

      @search = @order.line_items.ransack(params[:q])
      @line_items = @search.result.page(params[:page])
      @recent_orders = @customer.purchase_orders
                                .where('completed_at IS NOT NULL')
                                .where(account_id: @user_accounts.map(&:id))
                                .order('completed_at DESC').limit(5)
      #todo, ajax for new order for customers
      @days_available = nil
  		render :new
    end

    def create
      @customer = current_customer
      load_user_accounts
      account = @user_accounts.find_by_id(order_params[:account_id])
      @vendor = account.try(:vendor)

      @days_available = generate_days(account)
      if account && !account.can_select_delivery?
        params[:order][:delivery_date] = DateHelper.sweet_today(@vendor.try(:time_zone))
      elsif params[:order][:delivery_date].blank?
        params[:order][:delivery_date] = get_num_until_next_available_day(@days_available, account: account)[1]
        params[:order][:delivery_date] ||= DateHelper.sweet_today(@vendor.try(:time_zone))
      else
        format_form_date_field(:order, :delivery_date, @customer)
      end
      if account.present?
        @order = @customer.purchase_orders
                          .joins("LEFT JOIN spree_line_items ON spree_line_items.order_id = spree_orders.id")
                          .where(account_id: account.id)
                          .having("COUNT(spree_line_items.id) = 0")
                          .group("spree_orders.id")
                          .first
        if @order #resets the order
          now = Time.current
          due_date = params[:order][:delivery_date] + account.payment_days.days
          @order.update_columns(created_at: now,
                                updated_at: now,
                                user_id: nil,
                                invoice_date: params[:order][:delivery_date],
                                due_date: due_date)
          @order.update_columns(created_at: now, updated_at: now, user_id: nil, invoice_date: params[:order][:delivery_date])
        end
      else
        flash.now[:error] = "Please select an account"
        render :new and return
      end
      @order ||= @customer.purchase_orders.new(vendor_id: account.vendor_id, channel: Spree::Company::B2B_PORTAL_CHANNEL)
      @order.assign_attributes(order_params)
      @order.txn_class_id = account.try(:default_txn_class_id) if @order.vendor.track_order_class?
      @search = @order.line_items.ransack(params[:q])
      @line_items = @search.result.page(params[:page])
      @recent_orders = @customer.purchase_orders
                                .where('completed_at IS NOT NULL')
                                .where(account_id: @user_accounts.map(&:id))
                                .order('completed_at DESC').limit(5)
      associate_user(@order)

      @order.ship_address_id = params[:ship_address_id] if params[:ship_address_id]

      @order.set_shipping_method
      if @order.account.inactive?
        flash.now[:error] = "This account has been deactivated. Please contact #{@order.vendor.name} to reactivate your account before placing an order."
        render :new
      elsif !@order.valid_address?
        flash.now[:error] = "Invalid address. Please update your company shipping and billing address before starting an order."
        render :new
      elsif @order.valid_delivery_date?(@customer.date_format) && @order.save
        set_order_session(@order)
        flash[:success] = "You've started a new order!"
        redirect_to vendor_products_url(@order.vendor)
      else
        flash.now[:errors] = @order.errors.full_messages
        render :new
      end
    end

    def edit
      @order = set_order_session
      load_date_options(order: @order)

      # load order addresses if they exist, otherwise default to account addresses
      set_order_addresses

      @customer = @order.customer
      @vendor = @order.vendor
      @search = @order.line_items.select('spree_line_items.*, (price - price_discount) as discount_price, (quantity * (price - price_discount)) as amount').includes(variant: :product).ransack(params[:q])
      @search.sorts = @vendor.cva.try(:line_item_default_sort) if @search.sorts.empty?
      @line_items = @search.result.includes(line_item_lots: :lot)
      if @order.thread.comments.exists?
        commontator_thread_show(@order)
      end
      @recalculate_shipping = true if session[:recalculate_shipping]
      @payments = @order.payments.includes(refunds: :reason)
      @refunds = @payments.flat_map(&:refunds)
      @ship_addresses = @order.available_ship_addresses
      # @credit_cards = @account.credit_cards
      render :edit
    end

    def user_accounts
      @company = current_spree_user.company
      @customer = current_customer
      # current_vendor returns null
      @account = current_spree_user.accounts.find(params[:account_id])
      @user_account = current_spree_user.accounts.find(params[:account_id])
      if @user_account
        @vendor = @user_account.vendor
        # load order addresses if they exist, otherwise default to account addresses
        set_order_addresses

        load_date_options(account: @user_account)
        @date_selected = params[:date_selected]
        @next_available_day = @date_selected == 'true' ? nil : @next_available_day
      end

      respond_to do |format|
        format.js { render :user_accounts }
      end
    end

    def update
      @order = set_order_session
      @customer = @order.customer
      @vendor = @order.vendor
      @search = @order.line_items.includes(:product).ransack(params[:q])
      @search.sorts = @vendor.cva.try(:line_item_default_sort) if @search.sorts.empty?
      @line_items = @search.result.includes(line_item_lots: :lot)
      @payments = @order.payments.includes(refunds: :reason)
      @refunds = @payments.flat_map(&:refunds)
      @ship_addresses = @order.available_ship_addresses
      @reload_page = params[:reload].to_bool # use to reload page on ajax request
      commontator_thread_show(@order)
      format_form_date_field(:order, :delivery_date, @customer)
      if format_form_date_field(:order, :invoice_date, @customer) == @order.created_at.to_date
        params[:order][:invoice_date] = @order.created_at
      end
      if States[@order.state].between?(States['cart'], States['complete'])
        account = @order.account
        if account && !account.can_select_delivery?
          params[:order][:delivery_date] = DateHelper.sweet_today(@vendor.try(:time_zone))
        elsif params[:order][:delivery_date].blank?
          if @order.should_auto_update_delivery_date?
            params[:order][:delivery_date] = @order.next_available_delivery_date
            params[:order][:delivery_date] ||= DateHelper.sweet_tomorrow(@vendor.try(:time_zone))
          else
            params[:order][:delivery_date] = @order.delivery_date
          end
        end
      end

      errors = @order.create_shipment! if @order.shipments.none?
      if @order.update(order_params)
        update_totals
        session[:recalculate_shipping] = true if @order.active_shipping_calculator

        case params[:commit]
        when Spree.t(:submit_order)
          @order.update_columns(recalculate_shipping: false)
          @order.user_id = current_spree_user.id
          @order.channel = Spree::Company::B2B_PORTAL_CHANNEL
        when Spree.t(:resubmit_order)
          @order.update_columns(recalculate_shipping: false)
          @order.user_id = current_spree_user.id
        when 'Add Item'
          @order.contents.update_cart({})
          redirect_to vendor_products_url(@order.vendor) and return
        else
          flash[:success] = 'Your order has been successfully updated!'
        end

        if @order.account.inactive?
          flash[:errors] = ["This account has been deactivated. Please contact #{@order.vendor.name} to reactivate your account before placing an order."]
          respond_to do |format|
            format.html do
              load_date_options(order: @order)
              render :edit
            end
            format.js {render :add_to_cart}
          end
          return
        elsif [Spree.t(:submit_order), Spree.t(:resubmit_order)].include?(params[:commit]) \
          && @order.valid_for_customer_submit?
          begin
            @order.back_to_cart unless @order.state == 'cart'
            @order.next
          rescue Exception => e
            unless e.message.include?('Insufficient stock at')
              flash.now[:errors] = [e.message]
              respond_to do |format|
                format.html do
                  load_date_options(order: @order)
                  render :edit
                end
                format.js {render :add_to_cart}
              end
              return
            end
          end
          redirect_to success_order_path(@order)
        elsif @order.is_valid?
          respond_to do |format|
            format.html do
              unless @order.valid_delivery_date?(@customer.date_format) && @order.required_payment_made?
                flash[:errors] = @order.errors_including_line_items
              end
              redirect_to edit_order_path(@order)
            end
            format.js {render :add_to_cart}
          end
        else
          flash.now[:errors] = @order.errors_including_line_items \
            + @order.errors_from_order_rules
          respond_to do |format|
            format.html do
              load_date_options(order: @order)
              render :edit
            end
            format.js {render :add_to_cart}
          end
        end
      else
        respond_to do |format|
          flash[:success] = nil
          flash.now[:errors] = @order.errors_including_line_items
          format.html do
            load_date_options(order: @order)
            render :edit
          end
          format.js {render :add_to_cart}
        end
      end
    end

    def update_delivery_date
      format_form_date_field(nil, :delivery_date, current_vendor)
      @order = current_customer.purchase_orders.friendly.find(params[:id])
    end

    def update_totals
      @order.item_count = @order.quantity
      @order.persist_totals

      if @order.active_shipping_calculator
        @order.update_columns(recalculate_shipping: true)
      else
        @order.shipments.each do |s|
          s.refresh_rates
          s.update_amounts
        end
      end
      unless @order.contents.update_cart({order_state: @order.state})
        @order.item_count = @order.quantity
        @order.persist_totals
        Spree::OrderUpdater.new(@order).update
      end
    end

    def success
      @order = current_customer.purchase_orders.friendly.find(params[:id])
      clear_current_order
      render :success
    end

    def add_to_cart
      @order = Spree::Order.includes(:line_items, :adjustments, :payments, :shipments).find_by_id(session[:order_id])
      if @order.nil?
        @order = Spree::Order.includes(:line_items, :adjustments, :payments, :shipments).friendly.find(params[:order_id]) rescue nil
        session[:order_id] = @order.try(:id)
      end
      @reload_page = params[:reload].to_bool
      errors = ["Could not find order in your current session. Try selecting the order again."]
      unless @order.nil?
        errors = []
        if params[:order] && params[:order][:products]
          variants = params[:order][:products].keep_if do |id, qty|
            if qty.is_a? Hash
              qty[:quantity].to_f.between?(0.00001, 2_147_483_647)
            else
              qty.to_f.between?(0.00001, 2_147_483_647)
            end
          end
          errors = variants.empty? ? ['No products were selected'] : @order.contents.add_many(variants, {})
        end
      end
      if variants.count == 1
        @variant = @order.vendor.variants_including_master.find_by_id(
          variants.keys.first
        )
        @avv = @variant.avvs.where(account_id: @order.account_id).first
        @line_items = @order.line_items.where(variant_id: @variant.id)
      end
      session[:recalculate_shipping] = true if @order.changed? && @order.active_shipping_calculator
      if @order.state == 'approved' && !@order.vendor.try(:auto_approve_orders)
        @order.back_to_complete
      else
        @order.trigger_transition
      end
      respond_with(@order) do |format|
        if errors.present?
          format.html do
            flash[:errors] = errors
            redirect_to :back
          end
          format.js {flash.now[:errors] = errors}
        else
          format.html do
            flash[:success] = "Your order has been updated!"
            redirect_to edit_order_path(@order)
          end
          format.js { flash.now[:success] = "Your order has been updated!"}
        end
      end
    end

    def unpopulate
      error = nil
      @line_item = Spree::LineItem.find_by_id(params[:line_item_id])
      if @line_item
        @order = @line_item.order
        @line_item.quantity = 0 #set qty to zero so inventory is restocked
        if @line_item.destroy!
          load_date_options(order: @order)
          @order.back_to_cart if @order.line_items.count == 0
          @order.contents.update_cart({})
          if @order.changed? && @order.active_shipping_calculator
            @order.update_columns(recalculate_shipping: true)
          else
            @order.recalculate_shipping_rates
          end
          @order.update!
        else
          error = "Could not remove item."
        end
      end

      respond_with(@order, @line_item) do |format|
        format.js {flash.now[:error] = error}
      end
    end

    def recalculate_shipping
      begin
        @order = current_customer.purchase_orders.friendly.find(params[:order_id])
        @order.update_columns(recalculate_shipping: false)
        session.delete(:recalculate_shipping)
        @order.recalculate_shipping_rates
        @order.update!
        respond_to do |format|
          format.js
        end
      rescue Spree::ShippingError => e
        errors = if e.message == 'weight_error'
                   [Spree.t('active_shipping.customer_weight_error')]
                 else
                   [e.message]
                 end
        flash.now[:errors] = errors
      end
    end

    def destroy
      if @order.state != 'cart' && @order.canceled_by(try_spree_current_user)
        flash[:success] = "Order ##{@order.display_number} has been canceled"
        clear_current_order
      elsif @order.destroy
        clear_current_order
        flash[:success] = "Order ##{@order.display_number} has been canceled"
      else
        flash[:errors] = @order.errors.full_messages
      end
      redirect_to orders_url
    end

    def generate
      @order = Spree::Order.includes(:line_items, :account, customer: :users).friendly.find(params[:order_id])
      if @order.account.inactive?
        flash[:error] = "This account has been deactivated. Please contact #{@order.vendor.name} to reactivate your account before placing an order."
        redirect_to :back
      else
        order = Spree::Order.new(
          delivery_date: @order.next_available_delivery_date,
          vendor_id: @order.vendor_id,
          customer_id: @order.customer_id,
          account_id: @order.account_id,
          ship_address_id: @order.ship_address_id,
          bill_address_id: @order.bill_address_id,
          shipping_method_id: @order.account.try(:default_shipping_method_id) || @order.shipping_method_id
        )
        associate_user(order)
        if @order.vendor.track_order_class?
          order.txn_class_id = @order.try(:txn_class_id) ? @order.try(:txn_class_id) : @order.account.try(:default_txn_class_id)
        end
        order.save
        order.contents.add_many(Hash[@order.line_items.map.with_index do |item, idx|
          ["#{item.variant_id}_#{idx}", item.quantity]
        end], {})
        redirect_to edit_order_path(order), flash: { success: "Order has been created from Order ##{@order.display_number}" }
      end
    end

    def variant
      @order = current_customer.purchase_orders.friendly.find(params[:id])
      @vendor = @order.vendor
      @variant = @vendor.variants_for_sale.find(params[:variant_id])
      @avv = @variant.avvs.find_by(account_id: @order.account_id)
      @line_items = @order.line_items.where(variant_id: @variant.id)
      respond_with(@order, @variant, @avv)
    end

    def save_and_clear_order
      clear_current_order
      if params[:prev_controller].include?('orders')
        redirect_to orders_url
      elsif params[:prev_controller].include?('invoices')
        redirect_to invoices_url
      else
        redirect_to :back
      end
    end

    def set_ship_address_on_new
      @account = current_spree_user.accounts.find(params[:account_id])
      set_order_addresses
      @account_address_ship = @account.ship_addresses.find_by(id: params[:address_id])
      respond_to do |format|
        format.js do
          flash[:success] = 'Shipping address was successfully updated.'  unless params[:not_flash]
          render 'spree/cust/orders/addresses/set_ship_address_on_new.js.erb'
        end
      end
    end

    def set_ship_address
      if params[:order] && params[:order][:ship_address_id].present?
        @order.set_ship_address(params[:order][:ship_address_id])
        @vendor = @order.vendor
        @account = @order.account
        update_shipping_method
        @order.create_tax_charge!
        @order.update_totals

        if @order.save
          @ship_addresses = @order.available_ship_addresses
          @order.update_columns(recalculate_shipping: true) if @order.active_shipping_calculator

          set_order_addresses
          flash[:success] = 'Shipping address was successfully updated.'
        else
          flash.now[:errors] = @order.errors.full_messages
        end
      else
        flash.now[:errors] = 'Please add/select a shipping address.'
      end

      respond_to do |format|
        format.js do
          render 'spree/cust/orders/addresses/set_ship_address.js.erb'
        end
      end
    end

    def new_ship_address
      @order = current_customer.purchase_orders.includes(:line_items, :account, customer: :users).friendly.find(params[:order_id])

      @account = @order.account
      @address = @account.shipping_addresses.new

      respond_to do |format|
        format.js do
          render 'spree/cust/orders/addresses/new_ship_address.js.erb'
        end
      end
    end

    def create_and_assign_ship_address
      @order = current_customer.purchase_orders.includes(:line_items, :account, customer: :users).friendly.find(params[:order_id])
      @account = @order.account
      @address = @order.account.shipping_addresses.new(address_params)

      if @address.save

        @order.set_ship_address(@address.id)
        update_shipping_method
        @order.create_tax_charge!
        @order.update_totals

        if @order.save
          @ship_addresses = @order.available_ship_addresses
          @order.update_columns(recalculate_shipping: true) if @order.active_shipping_calculator
          set_order_addresses
          flash[:success] = 'Address was successfully created.'

        else
          flash.now[:errors] = @order.errors.full_messages
        end
      else
        flash.now[:errors] = @address.errors.full_messages
      end
      respond_to do |format|
        format.js do
          render 'spree/cust/orders/addresses/create_and_assign_ship_address.js.erb'
        end
      end
    end

    def new_bill_address
      @order = current_vendor.sales_orders.includes(:line_items, :account, customer: :users).friendly.find(params[:order_id])

      @account = @order.account
      @address = @account.billing_addresses.new

      respond_to do |format|
        format.js do
          render 'spree/cust/orders/addresses/new_bill_address.js.erb'
        end
      end
    end

    def create_bill_address
      @order = current_vendor.sales_orders.includes(:line_items, :account, customer: :users).friendly.find(params[:order_id])
      @account = @order.account
      @address = @account.billing_addresses.new(address_params)

      if @address.save
        @account.update_columns(bill_address_id: @address.id)
        @order.bill_address_id = @address.id
        if @order.save
          @ship_addresses = @order.available_ship_addresses
          set_order_addresses
          respond_to do |format|
            format.js do
              flash[:success] = 'Billing address was successfully created.'
              render 'spree/cust/orders/addresses/create_bill_address.js.erb'
            end
          end
        else
          respond_to do |format|
            format.js do
              flash.now[:errors] = @order.errors.full_messages
              render 'spree/cust/orders/addresses/create_bill_address.js.erb'
            end
          end
        end
      else
        respond_to do |format|
          format.js do
            flash.now[:errors] = @address.errors.full_messages
            render 'spree/cust/orders/addresses/create_bill_address.js.erb'
          end
        end
      end
    end

    def edit_bill_address
      @order = current_customer.purchase_orders.includes(:line_items, account: :bill_address, customer: :users).friendly.find(params[:order_id])
      @account = @order.account
      @address = @order.account.bill_address

      if @address.update(address_params)
        @order.bill_address_id = @address.id
        if @order.save
          @ship_addresses = @order.available_ship_addresses
          set_order_addresses
          respond_to do |format|
            format.js do
              flash[:success] = 'Billing address was successfully updated.'
              render 'spree/cust/orders/addresses/edit_bill_address.js.erb'
            end
          end
        else
          respond_to do |format|
            format.js do
              flash.now[:errors] = @order.errors.full_messages
              render 'spree/cust/orders/addresses/edit_bill_address.js.erb'
            end
          end
        end
      else
        respond_to do |format|
          format.js do
            flash.now[:errors] = @address.errors.full_messages
            render 'spree/cust/orders/addresses/edit_bill_address.js.erb'
          end
        end
      end
    end

    def set_order_addresses
      @account_address_ship = if @order.try(:ship_address)
                                @order.ship_address
                              elsif @account.try(:default_ship_address)
                                @account.default_ship_address
                              else
                                @account.ship_addresses.new
                              end
      @account_address_bill = if @order.try(:bill_address)
                                @order.bill_address
                              elsif @account.try(:bill_address)
                                @account.bill_address
                              else
                                @account.billing_addresses.new
                              end
    end

    protected

    def load_user_accounts
      if request.host == ENV['DEFAULT_URL_HOST']
        @user_accounts = @customer.vendor_accounts.includes(:vendor)
          .where(id: current_spree_user.user_accounts.pluck(:account_id))
          .order('fully_qualified_name ASC')
      else
        @user_accounts = @customer.vendor_accounts.joins(:vendor)
          .where('spree_companies.custom_domain = ?', request.host)
          .where('spree_accounts.id IN (?)', current_spree_user.user_accounts.pluck(:account_id))
          .order('fully_qualified_name ASC')
      end
    end

    def order_params
      params.require(:order).permit(:delivery_date, :vendor_id, :user_id, :special_instructions, :account_id, :credit_card_id,
      :ship_address_id, :bill_address_id, :created_by_id, :state, :completed_at, :shipping_method_id, :po_number, :invoice_date,
      line_items_attributes: [:quantity, :id]).tap do |ha|
        ha.fetch(:line_items_attributes, {}).values.each do |line_hash|
          line_hash[:quantity] = line_hash[:quantity].to_f
        end
      end
    end

    def address_params
      params.require(:address).permit(:id, :name, :firstname, :lastname, :company, :phone, :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id, :addr_type)
    end

    def credit_card_params
      params.require(:credit_card_info).permit(:number, :expiry, :verification_value, :cc_type, :name)
    end

    def ensure_can_resubmit
      @order ||= Spree::Order.friendly.find(params[:id])
      return if @order.state == 'cart'
      return if States[@order.state] >= States['shipped']

      case @order.vendor.resubmit_orders
      when 'never'
        flash[:error] = "This order has already been submitted. Please contact #{@order.vendor.name} to make any changes."
        redirect_to edit_order_path
      when 'complete'
        if States[@order.state] > States['complete']
          flash[:error] = "This order has already been approved. Please contact #{@order.vendor.name} to make any changes."
          redirect_to edit_order_path
        end
      when 'approved'
        if States[@order.state] > States['approved']
          flash[:error] = "This order has already been shipped. Please contact #{@order.vendor.name} to make any changes."
          redirect_to edit_order_path
        end
      end
    end

    def ensure_customer
      @order = Spree::Order.friendly.find(params[:id])
      unless spree_current_user.vendor_accounts.find_by_id(@order.try(:account_id)).present?
        flash[:error] = "You do not have permission to view order #{@order.try(:number)}"
        redirect_to root_url
      end
    end

    def ensure_order_in_time
      @order = Spree::Order.friendly.find(params[:id])
      if States[@order.state] >= States['approved']
        if @order.any_variant_past_cutoff?
          flash[:error] = "Some items in your order are past the cutoff time. Please contact #{@order.vendor.name} for cancelation policies."
          redirect_to order_url(@order)
        end
      end
    end

    def ensure_editable
      @order = Spree::Order.friendly.find(params[:id])
      unless @order.is_editable? && @order.is_submitable?
        flash[:error] = 'This order can no longer be edited'
        redirect_to order_url(@order)
      end
    end

    def ensure_valid_address
      @order = Spree::Order.friendly.find(params[:id])
      unless @order.valid_address?
        respond_to do |format|
          format.js do
            flash.now[:errors] = ["Invalid address. Please update your shipping and billing address."]
            render :add_to_cart
          end
          format.html do
            flash[:error] = "Invalid address. Please update your shipping and billing address."
            redirect_to edit_order_path(@order)
          end
        end
      end
    end

    def sort_column
      if params[:action] == 'index'
        if Spree::Order.column_names.include?(params[:sort])
          params[:sort]
        elsif params[:sort] == "spree_vendor.name"
          params[:sort]
        else
          "delivery_date"
        end
      elsif params[:action] == 'edit' || params[:action] == 'show'
        if Spree::LineItem.column_names.include?(params[:sort]) || params[:sort] == 'name'
          params[:sort]
        else
          'updated_at'
        end
      end
    end

    def sort_direction
      %w[asc desc].include?(params[:direction]) ?  params[:direction] : "desc"
    end

    def validate_payment_method_provider(payment_method_id)
      unless params[:payment_method]
        payment_type = Spree::PaymentMethod.find_by_id(payment_method_id).type
      else
        payment_type = params[:payment_method][:type]
      end
      valid_payment_methods = Sweet::Application.config.x.payment_methods.map(&:to_s)
    end

    def rescue_from_spree_gateway_error(exception)
      flash.now[:error] = Spree.t(:spree_gateway_error_flash_for_checkout)
      @order.errors.add(:base, exception.message)
      render :edit
    end

    def get_delivery_date
      if @order.try(:delivery_date).present?
        if @order.should_auto_update_delivery_date?
          if @order.id.present?
            deliver_date = @next_available_delivery_date
            delivery_date ||= @order.next_available_delivery_date(current_company.time_zone)
            @order.update_columns(
              delivery_date: delivery_date,
              invoice_date: delivery_date,
              due_date: delivery_date + @order.account.try(:payment_terms).try(:num_days).to_i.days
            )
            @order.reload
          else
            @order.delivery_date = @order.next_available_delivery_date(current_company.time_zone)
          end
        end
        date = DateHelper.display_vendor_date_format(@order.delivery_date, @customer.date_format)
      else
        time_zone = @customer.time_zone.present? ? @customer.time_zone : "Eastern Time (US & Canada)"
        date = Time.current.in_time_zone(time_zone).to_date + 1.day
      end
    end

    def update_shipping_method
      prev_shipping_method_id = @order.shipping_method_id
      @order.set_shipping_method
      return if @order.shipping_method_id == prev_shipping_method_id

      @order.shipment_total = 0
      @order.shipping_method_id = nil
      @order.shipments.first.update_columns(cost: 0)
    end
  end
 end
end
