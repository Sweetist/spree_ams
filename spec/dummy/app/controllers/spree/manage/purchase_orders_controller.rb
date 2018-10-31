module Spree
  module Manage
    class PurchaseOrdersController < Spree::Manage::BaseController

      helper_method :sort_column, :sort_direction
      respond_to :js

      before_action :clear_current_order, only: [:index, :new]
      before_action :ensure_company, only: [:show, :edit, :update, :destroy, :add_line_item, :void, :get_lot_qty]
      before_action :create_default_lot, only: [:new, :edit, :create, :update]
      before_action :ensure_purchase_orders_permission#, only: [:new, :create, :update, :edit, :index, :show, :void, :destroy, :add_line_item]

      def index
        params[:q] ||= {}
        @company = current_company
        @vendors = @company.customers.order('name ASC')
        order_hash = current_spree_user.permissions.fetch('order')
        @manual_adjustment = order_hash.fetch('manual_adjustment')
        @default_statuses = %w{cart complete approved shipped review invoice}
        @order_limit = @company.subscription_limit('purchase_order_history_limit')

        params[:q][:shipment_state_or_state_cont_any] = @default_statuses if params[:q][:shipment_state_or_state_cont_any].blank?
        format_ransack_date_field(:delivery_date_gteq, @company)
        format_ransack_date_field(:delivery_date_lteq, @company)
        format_ransack_date_field(:completed_at_gteq, @company)
        format_ransack_date_field(:completed_at_lteq, @company)
        if params[:q] && params[:q][:shipment_state_or_state_cont_any].include?('cart')
          params[:q][:created_at_lteq], params[:q][:created_at_gteq] = params[:q][:completed_at_lteq], params[:q][:completed_at_gteq]
          params[:q][:completed_at_lteq], params[:q][:completed_at_gteq] = nil, nil

          # Last order which is not carted or deleted
          if @order_limit
            params[:q][:created_at_gteq] = @company.purchase_orders.where.not(state:['cart','canceled']).order('created_at desc').limit(@order_limit).last.try(:created_at)
          end

          params[:q][:completed_at_lteq], params[:q][:completed_at_gteq] = params[:q][:created_at_lteq], params[:q][:created_at_gteq]
          params[:q][:created_at_lteq], params[:q][:created_at_gteq] = nil, nil

        else
          params[:q][:created_at_gteq] = @company.purchase_orders.where.not(state:['cart','canceled']).order('created_at desc').limit(@order_limit).last.try(:created_at)

          if @order_limit
            params[:q][:created_at_gteq] = @company.purchase_orders.where.not(state:['cart','canceled']).order('created_at desc').limit(@order_limit).last.try(:created_at)
          end
        end

        @any_orders_today = @company.purchase_orders.where(state: InvoiceableStates, delivery_date: overview_date_t).exists?
        @any_approved_orders_today = @company.purchase_orders.approved.where(delivery_date: overview_date_t).exists?
        @search = @company.purchase_orders.order('completed_at DESC').ransack(params[:q])
        respond_to do |format|
          format.html
          format.json { render json: SpreePurchaseOrderDatatable.new(view_context, vendor: current_company, user: current_spree_user, ransack_params: params[:q])}
        end

        revert_ransack_date_to_view(:delivery_date_gteq, @company)
        revert_ransack_date_to_view(:delivery_date_lteq, @company)
        revert_ransack_date_to_view(:completed_at_gteq, @company)
        revert_ransack_date_to_view(:completed_at_lteq, @company)
      end

      def new
        @company = current_company
        @stock_location = @company.default_stock_location || @company.stock_locations.first
        delivery_date = Time.current.in_time_zone(@company.time_zone).to_date
        @order = @company.purchase_orders.new(delivery_date: delivery_date,
                                              order_type: 'purchase',
                                              po_stock_location_id: @stock_location.id
                                            )

        @order.customer = @company # set customer to company b/c this does not happen automatically in previous step
        @search = @order.line_items.ransack(params[:q])
        @line_items = @search.result.page(params[:page])
        @vendor_accounts = @company.vendor_accounts.active.order('fully_qualified_name ASC')
        @days_available = nil
        @variants = @company.variants_for_purchase
                            .active
                            .includes(:product, :option_values)
                            .order('full_display_name asc')
        render :new
      end

      def create
        @company = current_company
        @account = @company.vendor_accounts.find_by_id(order_params.fetch(:account_id, nil))
        if @account && params[:order] && params[:order][:invoice_date].blank?
          params[:order][:invoice_date] = DateHelper.sweet_today(@company.try(:time_zone)).in_time_zone('UTC')
        elsif order_params.fetch(:invoice_date, nil).present?
          format_form_date_field(:order, :invoice_date, @company)
        end
        params[:order][:delivery_date] = order_params[:invoice_date]
        params[:order][:due_date] = order_params[:invoice_date] + @account.try(:payment_days).to_i.days
        if order_params[:account_id].present?
          @order = @company.purchase_orders.where('spree_orders.account_id = ? AND spree_orders.id NOT IN (SELECT spree_line_items.order_id FROM spree_line_items)', order_params[:account_id]).first
          if @order #resets the order
            now = Time.current
            @order.update_columns(created_at: now, updated_at: now, user_id: nil)
          end
          @order ||= @company.purchase_orders.new(order_params)

          # FOR PO, NEED TO SET THE @order.vendor and order_type = "purchase"
          @order.vendor = @account.vendor
          @order.order_type = "purchase"

          @search = @order.line_items.ransack(params[:q])
          @line_items = @search.result.page(params[:page])
          @vendor_accounts = @company.vendor_accounts.active.order('fully_qualified_name ASC')
          associate_user(@order)
          @order.account_id = order_params[:account_id].to_i

          @variants = @company.variants_for_purchase
                              .active
                              .includes(:product, :option_values)
                              .order('full_display_name asc')

          if (@order.persisted? && @order.update(order_params)) || (!@order.persisted? && @order.save)

            @order.ship_address_id = @order.bill_address_id # temporary hard-code to set ship address for customer
            @order.save

            set_purchase_order_session(@order)

            respond_with(@order) do |format|
              format.html do
                flash[:success] = "You've started a new order!"
                redirect_to edit_manage_purchase_order_path(@order)
              end
              format.js {}
            end
          else
            respond_with(@order) do |format|
              format.html do
                flash.now[:errors] = @order.errors.full_messages
                render :new
              end
              format.js do
                flash.now[:errors] = @order.errors.full_messages
              end
            end
          end
        else
          respond_with(@order) do |format|
            format.html do
              flash.now[:error] = "Please select a vendor"
              render :new
            end
            format.js do
              flash.now[:error] = "Please select a vendor"
            end
          end
        end
      end

      def show
        @bookkeeping_document =  @order.bookkeeping_documents.create(template: 'purchase_order')
        respond_with(@bookkeeping_document) do |format|
          format.pdf do
            send_data @bookkeeping_document.pdf, type: 'application/pdf', disposition: 'inline'
          end
        end
      end

      def vendor_accounts
        if request.params[:order_number].present?
          @order = current_company.purchase_orders.find_by_number(params[:order_number])
        end
        @account_id = request.params[:account_id]

        @vendor_account = current_company.vendor_accounts.find(@account_id)
        @account_address_ship = @vendor_account.default_ship_address
        @account_address_bill = @vendor_account.bill_address
        if @order && @vendor_account
          @order.update_columns(
            vendor_id: @vendor_account.try(:vendor_id),
            account_id: @account_id,
            ship_address_id: @account_address_ship.try(:id),
            bill_address_id: @account_address_bill.try(:id),
            email: @vendor_account.try(:email),
            user_id: current_spree_user.id
          )
        end
        @vendor = @vendor_account.customer
        @days_available = generate_days(@vendor_account)
        @date_selected = params[:date_selected]
        @next_available_day = get_num_until_next_available_day(@days_available)[0]
        @variants = current_company.variants_for_purchase
                                   .active
                                   .includes(:product, :option_values)
                                   .order('full_display_name asc')
        respond_to do |format|
         format.js do
            @account_id
            @vendor_account
            @vendor
            @days_available
            @company = @customer = current_company
            @next_available_day = @date_selected == 'true' ? nil : @next_available_day
            @account_address
            @date_selected
          end
        end
      end

      def generate_days(account)
        @account = account
        days_to_blackout = ""
        day_tracker = []
        available_days = "Vendor only delivers on "
        deliverable_days = @account.deliverable_days
        if deliverable_days["0"] && deliverable_days["6"] && !deliverable_days["1"] && !deliverable_days["2"] && !deliverable_days["3"] && !deliverable_days["4"] && !deliverable_days["5"]
          available_days = "Vendor only delivers on weekends"
          days_to_blackout = "1,2,3,4,5"
        elsif !deliverable_days["0"] && !deliverable_days["6"] && deliverable_days["1"] && deliverable_days["2"] && deliverable_days["3"] && deliverable_days["4"] && deliverable_days["5"]
          available_days = "Vendor only delivers on weekdays"
          days_to_blackout = "0,6"
        elsif !deliverable_days["0"] && !deliverable_days["6"] && !deliverable_days["1"] && !deliverable_days["2"] && !deliverable_days["3"] && !deliverable_days["4"] && !deliverable_days["5"]
          available_days = "Vendor currently does not deliver"
          days_to_blackout = "0,1,2,3,4,5,6"
        elsif deliverable_days["0"] && deliverable_days["6"] && deliverable_days["1"] && deliverable_days["2"] && deliverable_days["3"] && deliverable_days["4"] && deliverable_days["5"]
          available_days = "Vendor delivers every day"
          days_to_blackout = ""
        else
          @account.delivery_on_sunday ? day_tracker.push('Sundays') : days_to_blackout += '0,'
          @account.delivery_on_monday ? day_tracker.push('Mondays') : days_to_blackout += '1,'
          @account.delivery_on_tuesday ? day_tracker.push('Tuesdays') : days_to_blackout += '2,'
          @account.delivery_on_wednesday ? day_tracker.push('Wednesdays') : days_to_blackout += '3,'
          @account.delivery_on_thursday ? day_tracker.push('Thursdays') : days_to_blackout += '4,'
          @account.delivery_on_friday ? day_tracker.push('Fridays') : days_to_blackout += '5,'
          @account.delivery_on_saturday ? day_tracker.push('Saturdays') : days_to_blackout += '6,'

          available_days += day_tracker.to_sentence

        end
        return days_to_blackout, available_days
      end

      def get_num_until_next_available_day(days_available)
        blackout_days = days_available[0]
        if blackout_days != "0,1,2,3,4,5,6"
          next_available_day = Time.now.to_date + 1
          counter = 1
          while(blackout_days.include? next_available_day.wday.to_s)
            next_available_day += 1
            counter += 1
          end
          return counter.to_s + "d", next_available_day
        else
          return nil, nil
        end
      end

      def edit
        @order = set_purchase_order_session
        #@days_available = generate_days(@order.account)
        order_hash = current_spree_user.permissions.fetch('order')
        @user_edit_line_item = order_hash.fetch('edit_line_item') \
                                && @order.try(:can_edit_line_item?)

        @vendor = @order.vendor
        @company = current_company
        @search = @order.line_items.select('spree_line_items.*, (price - price_discount) as discount_price, (quantity * (price - price_discount)) as amount').includes(variant: :product).ransack(params[:q])
        @line_items = @search.result

        @variants = @company.variants_for_purchase
                            .active
                            .includes(:product, :option_values)
                            .order('full_display_name asc')

        render :edit
      end

      def update
        @company = current_company
        @order = @company.purchase_orders.includes(:line_items, shipments: :inventory_units).friendly.find(params[:id])
        #@days_available = generate_days(@order.account)
        @vendor = @order.vendor
        @search = @order.line_items.ransack(params[:q])
        @line_items = @search.result
        @variants = @company.variants_for_purchase
                            .active
                            .includes(:product, :option_values)
                            .order('full_display_name asc')

        order_hash = current_spree_user.permissions.fetch('order')
        @user_edit_line_item = order_hash.fetch('edit_line_item') \
                                && @order.try(:can_edit_line_item?)

        format_form_date_field(:order, :invoice_date, @company)

        params[:order][:delivery_date] = order_params[:invoice_date]
        params[:order][:due_date] = order_params[:invoice_date] + @account.try(:payment_days).to_i.days
        #only setting this if it is left blank, not if the param is not sent at all
        if params[:order] && params[:order][:shipment_total] == ''
          params[:order][:shipment_total] = 0.0
        end
        # @order.create_shipment! if @order.shipments.none?
        if @order.update(order_params)
          @order.item_count = @order.quantity
          @order.persist_totals
          case params[:commit]
          when Spree.t(:add_item)
            handle_success_render(manage_products_path)
          when Spree.t(:submit)
            if @order.is_valid?
              @order.next
              flash[:success] = "Order ##{@order.display_number} submitted"
              handle_success_render(manage_purchase_orders_path)
            else
              flash.now[:errors] = @order.errors_including_line_items.reject(&:blank?)
              render :edit
            end
          when Spree.t(:resubmit_order)
            if @order.is_valid?
              @order.trigger_transition
              Spree::OrderMailer.purchase_order_resubmit_email(@order).deliver_later if @order.account.send_purchase_orders_emails
              flash[:success] = "Order ##{@order.display_number} resubmitted"
              handle_success_render(manage_purchase_orders_path)
            else
              flash.now[:errors] = @order.errors_including_line_items.reject(&:blank?)
              render :edit
            end
          when Spree.t(:receive_order)
            errors = @order.receive(current_spree_user)

            if errors.blank?
              flash[:success] = "Purchase Order Received!"
              handle_success_render(manage_purchase_orders_path)
            else
              flash.now[:errors] = errors
              render :edit
            end
          when Spree.t(:void_order)
            errors = @order.void(current_spree_user)

            if errors.blank?
              flash[:success] = "Purchase Order Voided!"
              handle_success_render(manage_purchase_orders_path)
            else
              flash.now[:errors] = errors
              render :edit
            end
          else
            @order.trigger_transition if States[@order.state] > States['cart']
            flash[:success] = "Your order has been successfully updated!"
            handle_success_render(edit_manage_purchase_order_path(@order))
          end

          @order.shipments.each do |s|
            s.refresh_rates
            s.update_amounts
          end
          unless @order.contents.update_cart({order_state: @order.state})
            @order.item_count = @order.quantity
            @order.persist_totals
            Spree::OrderUpdater.new(@order).update
          end

          # don't do if just approved above
          if @order.state == 'approved' && !@recently_approved
            @order.back_to_complete
            # if @order.meets_minimum?
            #   @order.approve(current_spree_user)
            # else
            #   flash[:error] = "This order does not meet the order minimum. You must manually approve it again."
            # end
          end

        else
          flash[:success] = nil
          flash.now[:errors] = @order.errors.full_messages
          render :edit
        end
      end

      # Adds a new item to the order (creating a new order if none already exists)
      def populate
        order = current_order
        variant  = Spree::Variant.find(params[:index])
        quantity = params[:quantity].to_f
        options  = params[:options] || {}

        # 2,147,483,647 is crazy. See issue #2695.
        if quantity.between?(0.00001, 2_147_483_647)
          begin
            order.contents.add(variant, quantity, options)
          rescue ActiveRecord::RecordInvalid => e
            error = e.record.errors.full_messages.join(", ")
          end
        else
          error = Spree.t(:please_enter_reasonable_quantity)
        end

        respond_with(order) do |format|
          if error
            format.js { flash[:error] = error }
          else
            format.js { flash.now[:success] = "#{variant.product.name} has been added to your order"}
          end
        end
      end

      def unpopulate
        error = nil
        @line_item = Spree::LineItem.find_by_id(params[:line_item_id])
        if @line_item
          @order = @line_item.order
          @line_item.quantity = 0 #set qty to zero so inventory is restocked
          if @line_item.destroy
            @order.contents.update_cart({})
            if @order.line_items.count == 0
              @order.back_to_cart
            elsif @order.state == 'approved'
              @order.back_to_complete
              @order.approve(current_spree_user)
            end
          else
            error = "Could not remove item."
          end
        end

        respond_with(@order, @line_item) do |format|
          format.js {flash.now[:error] = error}
        end
      end

      def add_line_item
        errors = []
        begin
          @order = current_company.purchase_orders.friendly.find(params[:id])
          @variant = current_company.variants_including_master.find(params[:variant_id])
          @avv = @order.account.account_viewable_variants.where(variant_id: @variant.id).first
          errors = @order.contents.add_many({params[:variant_id] => params[:variant_qty].to_f}, {order_type: :purchase})
          @line_item = @order.line_items.where(variant_id: params[:variant_id]).last

          if @order.state == 'approved'
            @order.back_to_complete
            @order.approve(current_spree_user)
          end

        rescue Exception => e
          errors = [e.message]
        end

        flash.now[:errors] = errors if errors.any?
        render :add_line_item
      end

      def variant_search
        @company = current_company
        @order = @company.purchase_orders.friendly.find(params[:order_id]) rescue nil
        @variants = @company.variants_for_purchase
                            .active
                            .includes(:product, :option_values)
                            .order('full_display_name asc')
        respond_with(@variants)
      end

      def receive_at
        @stock_location = current_company.stock_locations.find_by_id(params[:stock_location_id])
      end

      def get_lot_qty
        @line_item = @order.line_items.find(params[:line_item_id])
        respond_to do |format|
          format.js do
            @line_item
          end
        end
      end

      def create_lot
        @company = current_company
        @line_item = Spree::LineItem.find(params[:line_item_id])
        @order = @line_item.order
        @variant = @company.variants_including_master.find_by_id(params[:lot][:variant_id])

        if params[:lot] && params[:lot][:available_at].present?
          params[:lot][:available_at] = params[:lot][:available_at] = DateHelper.company_date_to_UTC(params[:lot][:available_at], @company.date_format)
        end
        if params[:lot] && params[:lot][:expires_at].present?
          params[:lot][:expires_at] = params[:lot][:expires_at] = DateHelper.company_date_to_UTC(params[:lot][:expires_at], @company.date_format)
        end
        if params[:lot] && params[:lot][:sell_by].present?
          params[:lot][:sell_by] = params[:lot][:sell_by] = DateHelper.company_date_to_UTC(params[:lot][:sell_by], @company.date_format)
        end
        @lot = @company.lots.new(lot_params)

        unless @lot.save
          flash.now[:errors] = @lot.errors.full_messages
        end

        render 'spree/manage/orders/lots/create_lot'
      end

      def submit_lot_count
        @line_item = current_company.purchase_line_items.find_by_id(params[:line_item_id])
        @order = @line_item.order
        order_hash = current_spree_user.permissions.fetch('order')
        @user_edit_line_item = order_hash.fetch('edit_line_item') \
                                && @order.try(:can_edit_line_item?)
        @approve_ship_receive = order_hash.fetch('approve_ship_receive')
        begin
          ActiveRecord::Base.transaction do
            if params[:line_item_lots].present? && params[:line_item_id].present?
              line_item_lots = params[:line_item_lots]
              receive_at = @order.po_stock_location
              line_item_lots.each do |lot_id, count|
                new_line_item_lot = Spree::LineItemLots.find_or_initialize_by(lot_id: lot_id, line_item_id: params[:line_item_id])
                lot = new_line_item_lot.lot
                change_qty = count.to_d - new_line_item_lot.count
                new_line_item_lot.count = count
                if new_line_item_lot.count > 0
                  new_line_item_lot.save
                else
                  new_line_item_lot.destroy!
                end
                next if change_qty.zero?

                if @order.received?
                  stock_item = @line_item.variant.stock_items.find_by(stock_location_id: receive_at.try(:id))
                  stock_item_lot = lot.stock_item_lots.where(stock_item_id: stock_item.try(:id)).first
                  if stock_item_lot.nil? && stock_item.try(:id).present?
                    stock_item_lot = lot.stock_item_lots.create(stock_item_id: stock_item.id)
                  end
                  lot.move_qty(change_qty, stock_item_lot)
                end
              end
            end

            if params[:line_quantity] && params[:line_quantity].to_d != @line_item.quantity
              @line_item.quantity = params[:line_quantity].to_d
              @line_item.ordered_qty = params[:line_quantity].to_d unless @order.received?
              @line_item.save!
              @qty_changed = true
              @order.reload.shipments.each do |s|
                s.refresh_rates
                s.update_amounts
              end
              unless @order.contents.update_cart({order_state: @order.state})
                @order.item_count = @order.quantity
                @order.persist_totals
                Spree::OrderUpdater.new(@order).update
              end
            end
            flash.now[:success] = "Line successfully updated."
          end
        rescue Exception => e
          flash.now[:errors] = [e.message]
        end
      end

      def void
        @order = Spree::Order.friendly.find(params[:id])
        unless current_spree_user.can_write?('basic_options', 'purchase_orders')
          flash[:error] = 'You do not have permission to void transactions'
          redirect_to :back and return
        end

        if @order.void(current_spree_user.try(:id))
          flash[:success] = "Purchase order #{@order.display_number} has been voided."
          redirect_to manage_purchase_orders_path
        else
          flash[:errors] = @order.errors.full_messages
          redirect_to :back
        end
     end

      def destroy
        @order = set_purchase_order_session
        if @order.state != "cart" && @order.canceled_by(try_spree_current_user)
          flash[:success] = "Order ##{@order.display_number} has been canceled"
          clear_current_order
        elsif @order.destroy
          clear_current_order
          flash[:success] = "Purchase order ##{@order.display_number} has been canceled"
        else
          flash[:errors] = @order.errors.full_messages
        end
        redirect_to manage_purchase_orders_url
      end

      protected

      def handle_success_render(redirect_path)
        respond_with(@order) do |format|
          format.js do
            render js: "window.location.href = '" + redirect_path + "'"
          end
          format.html do
            redirect_to redirect_path
          end
        end
      end

      private

      def order_params
        params.require(:order).permit(:customer_id, :delivery_date, :special_instructions,
          :user_id, :state, :completed_at, :shipping_method_id, :po_number, :account_id,
          :shipment_total, :override_shipment_cost, :po_stock_location_id,
          :invoice_date, :due_date,
          :sweetist_fulfillment_time, :sweetist_fulfillment_time_window,
          shipments_attributes: [:tracking, :id],
          line_items_attributes: [:item_name, :quantity, :shipped_qty, :ordered_qty,
            :variant_id, :price, :lot_number, :id,
            line_item_lots_attributes: [:lot_id, :count, :variant_part_id, :id]
            ]).tap do |ha|
              ha.fetch(:line_items_attributes, {}).values.each do |line_hash|
                next unless line_hash[:quantity]
                line_hash[:quantity] = line_hash[:quantity].to_f
                line_hash[:price] = line_hash[:price].to_f
              end
            end
      end

      def approve_params
        params.require(:vendor).permit(:id,
          orders_attributes: [:approved, :order_id]
        )
      end

      def lot_params
        params.require(:lot).permit(:variant_id, :sell_by, :expires_at, :available_at, :number)
      end

      def ensure_company
        @order = current_company.purchase_orders.friendly.find(params[:id]) rescue nil
        unless @order
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to root_url
        end
      end

      def ensure_purchase_orders_permission
        unless current_spree_user.can_write?('basic_options', 'purchase_orders')
          flash[:error] = 'You do not have permission to view purchase orders'
          redirect_to manage_path
        end
      end


      def create_default_lot
        @lot = current_company.lots.new
      end

    end
  end
end
