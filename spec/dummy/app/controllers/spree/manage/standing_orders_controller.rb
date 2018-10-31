class Spree::Manage::StandingOrdersController < Spree::Manage::BaseController


  helper_method :sort_column, :sort_direction
  respond_to :js

  before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
  before_action :clear_current_order
  before_action :ensure_view_permission, only: [:show, :index]
  before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :clone]
  before_action :ensure_subscription_limit, only: [:new, :create, :clone]

  def index
    params[:q] ||= {}
    @vendor = current_vendor
    params[:q] = nil if params[:commit] == 'Reset'
		params[:commit] = nil
    @search = @vendor.sales_standing_orders('created_at DESC').ransack(params[:q])
    @orders = @search.result.includes(:account, :vendor, standing_line_items: :variant).page(params[:page])
    @customer_accounts = @vendor.customer_accounts.active.order('fully_qualified_name ASC')
    @standing_order_limit = @vendor.subscription_limit('standing_order_limit')
    respond_with(:manage, @orders)
  end

  def new
    @vendor = current_vendor
    @customer_accounts = @vendor.customer_accounts.active.order('fully_qualified_name ASC')
    @shipping_methods = current_vendor.shipping_methods
    @order = current_vendor.sales_standing_orders.new
    render :new
  end

  def customer_accounts
    @account = current_vendor.customer_accounts.find(params[:account_id])
    @order = current_vendor.sales_standing_orders.new
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

  def create

    @vendor = current_vendor
    @customer_accounts = @vendor.customer_accounts.active.order('fully_qualified_name ASC')

    format_form_date_field(:standing_order, :start_at, @vendor)
    format_form_date_field(:standing_order, :end_at_data_2_by, @vendor)

    @order = current_vendor.sales_standing_orders.new(order_params)
    if !order_params[:account_id].blank?

      @order.account_id = order_params[:account_id].to_i

      if @order.save
        flash[:success] = "New Standing Order has been created!"
        redirect_to edit_manage_standing_order_path(@order.id)
      else
        flash.now[:errors] = @order.errors.full_messages
        render :new
      end
    else
      flash.now[:error] = "Please select a customer account"
      render :new
    end
  end

  def show
    redirect_to edit_manage_standing_order_path(params[:id])
  end

  def edit
    @shipping_methods = current_vendor.shipping_methods
    @search = @order.standing_line_items.ransack(params[:q])
    @search.sorts = @vendor.cva.try(:standing_line_item_default_sort) if @search.sorts.empty?
    @standing_line_items = @search.result.includes(variant: :product)
    respond_with(:manage, @order)
  end

  def update_line_items_position
    params[:order].each do |key,value|
      Spree::StandingLineItem.find(value[:id]).update_attribute(:position, value[:position])
    end
    render :nothing => true
  end

  def update
    @vendor = current_vendor
    @shipping_methods = @vendor.shipping_methods
    @order.start_tracking!

    format_form_date_field(:standing_order, :start_at, @vendor)
    format_form_date_field(:standing_order, :end_at_data_2_by, @vendor)

    if @order.update(order_params)
      @order.touch
      if params[:commit] == 'Add Items'
        redirect_to manage_standing_order_products_path(@order.id) and return
      else
        flash[:success] = "Successfully updated Standing Order #{@order.name}!"
        redirect_to edit_manage_standing_order_path(@order.id)
      end
		else
      @search = @order.standing_line_items.ransack(params[:q])
      @search.sorts = @vendor.cva.try(:standing_line_item_default_sort) if @search.sorts.empty?
      @standing_line_items = @search.result.includes(variant: :product)
      flash.now[:errors] = @order.errors.full_messages
			render :edit
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
        bill_address_id: @order.account.try(:bill_address)
      )
      associate_user(order)
      order.set_shipping_method
      if @order.vendor.track_order_class?
        order.txn_class_id = @order.try(:txn_class_id) ? @order.try(:txn_class_id) : @order.account.try(:default_txn_class_id)
      end
      if order.save
        errors = @order.add_lines_to_order(order)
        flash[:errors] = errors unless errors.empty?
        redirect_to edit_manage_order_path(order), flash: { success: "Order has been created from Standing Order #{@order.name}" }
      else
        flash.now[:errors] = order.errors.full_messages
        render :edit
      end

    else
    end
  end

  def clone
    @order = current_company.sales_standing_orders.find(params[:standing_order_id])
    so = @order.clone

    if so.save
      flash[:success] = "Standing order copied from #{@order.name}"
      redirect_to edit_manage_standing_order_path(so)
    else
      flash[:error] = so.errors.full_messages
      redirect_to :back
    end
  end

  def variant_search
    @vendor = current_vendor
    @order = @vendor.sales_standing_orders.find(params[:order_id]) rescue nil
    @variants = @vendor.variants_for_sale.order('full_display_name asc').includes(:option_values)
    respond_with(@variants)
  end

  def add_line_item
    errors = []
    begin
      @order = current_vendor.sales_standing_orders.find(params[:id])
      @order.start_tracking!

      @variant = current_vendor.variants_including_master.find(params[:variant_id])
      @avv = @order.account.account_viewable_variants.where(variant_id: @variant.id).first
      unless @order.add_many({params[:variant_id] => params[:variant_qty].to_f}, {})
        errors = @order.errors.full_messages
      end
      @line_item = @order.standing_line_items.where(variant_id: params[:variant_id]).last
      account_id = @order.account_id
      @order_total = @order.standing_line_items.includes(variant: :account_viewable_variants).map do |item|
        avv = item.variant.account_viewable_variants.where(account_id: @order.account_id).first
        item.quantity.to_f * avv.price.to_f
      end.inject(:+)

    rescue Exception => e
      errors = [e.message]
    end

    flash.now[:errors] = errors if errors.any?
    render :add_line_item
  end

  def unpopulate
    error = nil
    @order = current_vendor.sales_standing_orders.find(params[:id])
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

  def destroy
    if @order.destroy
      flash[:success] = "Standing order #{@order.name} deleted."
    else
      flash[:error] = "Could not delete standing order #{@order.try(:name)}"
    end

    redirect_to manage_standing_orders_path
  end

  protected

  def order_params
    params.require(:standing_order).permit(
      :customer_id,
      :account_id,
      :vendor_id,
      :user_id,
      :shipping_method_id,
      :name,
      :txn_class_id,
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
      :auto_approve,
      standing_line_items_attributes: [:quantity, :pack_size, :lot_number, :variant_id, :id, :txn_class_id]
    )
  end

  def ensure_vendor
    @order = Spree::StandingOrder.includes(standing_line_items: [variant: [:prices, :option_values]]).find(params[:id])
    unless current_vendor.id == @order.vendor_id
      flash[:error] = "You don't have permission to view the requested page"
      redirect_to root_url
    end
  end

  def ensure_view_permission
    if current_spree_user.cannot_read?('basic_options', 'standing_orders')
      flash[:error] = 'You do not have permission to view standing orders'
      redirect_to manage_path
    end
  end

  def ensure_write_permission
    if current_spree_user.cannot_read?('basic_options', 'standing_orders')
      flash[:error] = 'You do not have permission to view standing orders'
      redirect_to manage_path
    elsif current_spree_user.cannot_write?('basic_options', 'standing_orders')
      flash[:error] = 'You do not have permission to edit standing orders'
      redirect_to manage_path
    end
  end

  def ensure_subscription_limit
    @vendor = current_vendor

    @order_limit = @vendor.subscription_limit('standing_order_limit')
    unless @vendor.within_subscription_limit?('standing_order_limit', @vendor.sales_standing_orders.count)
      flash[:error] = "Your subscription is limited to #{@order_limit} standing #{'order'.pluralize(@order_limit)}."
      redirect_to manage_standing_orders_path
    end
  end

end
