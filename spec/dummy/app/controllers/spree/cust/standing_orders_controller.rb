class Spree::Cust::StandingOrdersController < Spree::Cust::CustomerHomeController

  helper_method :sort_column, :sort_direction
  respond_to :js

  before_action :ensure_customer, only: [:show, :edit, :update, :destroy]
  before_action :clear_current_order
  def index
    @customer = current_customer
    params[:q] = nil if params[:commit] == 'Reset'
		params[:commit] = nil

    @search = @customer.purchase_standing_orders.where(account_id: current_spree_user.account_ids).ransack(params[:q])
    @orders = @search.result.includes(:account, :vendor).page(params[:page])

    respond_with(@orders)
  end

  def new
    @customer = current_customer
    @vendor_shipping = @customer.vendors.uniq.first.shipping_methods
    @order = @customer.purchase_standing_orders.new
    @user_accounts = @customer.vendor_accounts.where(id: current_spree_user.user_accounts.pluck(:account_id))
    render :new
  end

  def create
    @customer = current_customer
    @vendors = @customer.vendors
    @vendor = @vendors.first
    @user_accounts = @customer.vendor_accounts.where(id: current_spree_user.user_accounts.pluck(:account_id))

    format_form_date_field(:standing_order, :start_at, @vendor)
    format_form_date_field(:standing_order, :end_at_data_2_by, @vendor)

    @order = @customer.purchase_standing_orders.new(order_params)

    @order.user_id = @order.customer.users.first.id
    @order.account_id = params[:standing_order][:account_id].to_i
    @order.vendor_id = @vendor.id
    @order.user_id ||= order.account.customer.users.any? ? order.account.customer.users.first.id : current_spree_user.id

    if @order.account.blank?
      flash.now[:error] = "Please select an account"
      render :new
    elsif @order.account.inactive?
      flash.now[:error] = "This account has been deactivated. Please contact #{@order.vendor.name} to reactivate your account before placing an order."
      render :new
    elsif @order.save
      session[:vendor_id] = @order.vendor_id
      redirect_to standing_order_products_path(@order.id), flash: { success: "New Standing Order has been created!" }
    else
      render :new, flash: { errors: @order.errors.full_messages }
    end

  end

  def show
    redirect_to edit_standing_order_path(params[:id])
  end

  def edit
    @customer = current_customer
    @vendors = current_customer.vendors
    @vendor_shipping = @vendors.uniq.first.shipping_methods
    @order = Spree::StandingOrder.find(params[:id])
    @account = @order.account
    @vendor = @account.try(:vendor)
    @user_accounts = @customer.vendor_accounts.where(id: current_spree_user.user_accounts.pluck(:account_id))
    respond_with(@order)
  end

  def update
    @customer = current_customer
    @vendors = current_customer.vendors
    @vendor = @vendors.first
    @order = Spree::StandingOrder.find(params[:id])
    @account = @order.account
    @user_accounts = @customer.vendor_accounts.where(id: current_spree_user.user_accounts.pluck(:account_id))
    @order.start_tracking!

    format_form_date_field(:standing_order, :start_at, @vendor)
    format_form_date_field(:standing_order, :end_at_data_2_by, @vendor)

    if params[:standing_order][:products]
      params[:standing_order][:products].keys.each do |line_id|
        quantity = params[:standing_order][:products][line_id].to_f
        line = @order.standing_line_items.find_by_id(line_id)
        if line && quantity.between?(1, 2_147_483_647)
          line.quantity = quantity
          line.save
        end
      end
    end

    if @order.update_attributes(order_params)
      @order.update_columns(timing_process: false) if @order.errors_from_order_rules.any?
      if params[:commit] == 'Add Items'
        redirect_to standing_order_products_path(@order.id) and return
      else
        flash[:success] = "Successfully updated Standing Order #{@order.name}!"
        redirect_to edit_standing_order_path(@order.id)
      end
		else
      flash.now[:errors] = @order.errors.full_messages
			render :edit
		end

	end

   def user_accounts
    @account = current_customer.vendor_accounts.find(params[:account_id])
    @order = current_customer.sales_standing_orders.new
    @account_address_ship = @account.default_ship_address
    @account_address_bill = @account.bill_address
    respond_to do |format|
      format.js do
          @order
          @account
          @account_address_bill
          @account_address_ship
       end
    end
  end

  def generate
    if request.post?
      @order = Spree::StandingOrder.includes(:standing_line_items).find(params[:standing_order_id])
      order = Spree::Order.new(
        delivery_date: Date.current,
        vendor_id: @order.vendor_id,
        customer_id: @order.customer_id,
        account_id: @order.account_id,
        ship_address_id: @order.account.try(:default_ship_address_id),
        bill_address_id: @order.account.try(:bill_address_id)
      )
      associate_user(order)
      order.set_shipping_method
      if order.save
        errors = @order.add_lines_to_order(order)
        flash[:errors] = errors unless errors.empty?
        redirect_to edit_order_path(order), flash: { success: "Order has been created from Standing Order #{@order.name}" }
      else
        flash.now[:errors] = order.erros.full_messages
        render :edit
      end
    end
  end

  def skip
    if request.put?
      @order = Spree::StandingOrder.find(params[:standing_order_id])
      schedule = @order.standing_order_schedules.find(params[:standing_order_schedule_id])
      schedule.skip = true
      schedule.save
      redirect_to edit_standing_order_path(@order), flash: { success: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} will be skipped!" }
    else
      redirect_to edit_standing_order_path(@order), flash: { error: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} cannot be enqueued!" }
    end
  end

  def enque
    if request.put?
      @order = Spree::StandingOrder.find(params[:standing_order_id])
      schedule = @order.standing_order_schedules.find(params[:standing_order_schedule_id])
      schedule.skip = false
      schedule.save
      redirect_to edit_standing_order_path(@order), flash: { success: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} is scheduled!" }
    else
      redirect_to edit_standing_order_path(@order), flash: { error: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} cannot be skipped!" }
    end
  end

  def unpopulate
    error = nil
    @order = Spree::StandingOrder.find(params[:id])
    @line_item = @order.standing_line_items.find_by_id(params[:line_item_id])

    if @line_item
      unless @line_item.destroy
        error = "Could not remove item."
      end
      @order_total = @order.standing_line_items.includes(variant: :account_viewable_variants).map do |item|
        avv = item.variant.account_viewable_variants.where(account_id: @order.account_id).first
        item.quantity.to_f * avv.price.to_f
      end.inject(:+)
    end

    respond_with(@order, @line_item) do |format|
      format.js {flash.now[:error] = error}
    end
  end

  protected

  def order_params
    params.require(:standing_order).permit(
      :customer_id,
      :vendor_id,
      :user_id,
      :account_id,
      :shipping_method_id,
      :name,
      :frequency_id,
      :frequency_data_1_monday,
      :frequency_data_1_tuesday,
      :frequency_data_1_wednesday,
      :frequency_data_1_thursday,
      :frequency_data_1_friday,
      :frequency_data_1_saturday,
      :frequency_data_1_sunday,
      :frequency_data_2_every,
      :frequency_data_2_day_of_week,
      :frequency_data_3_type,
      :frequency_data_3_month_number,
      :frequency_data_3_week_number,
      :frequency_data_3_every,
      :start_at,
      :end_at_id,
      :end_at_data_1_after,
      :end_at_data_2_by,
      :timing_id,
      :timing_create,
      :timing_remind,
      :timing_process,
      :timing_data_create_days,
      :timing_data_create_at_hour,
      :timing_data_remind_days,
      :timing_data_remind_at_hour,
      :timing_data_process_hours,
      :timing_data_process_at_hour,
      :timing_data_process_days,
      standing_line_items_attributes: [:quantity]
    )
  end

  def ensure_customer
    @order = Spree::StandingOrder.find(params[:id])
    unless current_spree_user.vendor_accounts.find_by_id(@order.try(:account_id)).present?
      flash[:error] = "You don't have permission to view the requested page"
      redirect_to root_url
    end
  end

end
