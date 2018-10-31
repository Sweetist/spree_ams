class Spree::Manage::StandingOrderSchedulesController < Spree::Manage::BaseController
  helper_method :sort_column, :sort_direction
  before_action :ensure_write_permission

  respond_to :js

  def index
    @vendor = current_company
    date = Date.current

    format_ransack_date_field(:deliver_at_gteq, @vendor)
    format_ransack_date_field(:deliver_at_lteq, @vendor)

    zone = @vendor.try(:time_zone) || 'UTC'
    tz_offset = ActiveSupport::TimeZone.new(zone).now.utc_offset
    if params.fetch(:q, {}).fetch(:deliver_at_gteq, nil).present?
      date_start = params[:q][:deliver_at_gteq]
      params[:q][:deliver_at_gteq] = date_start.beginning_of_day - tz_offset
    end
    if params.fetch(:q, {}).fetch(:deliver_at_lteq, nil).present?
      date_end = params[:q][:deliver_at_lteq]
      params[:q][:deliver_at_lteq] = date_end.end_of_day - tz_offset
    end

    @search = Spree::StandingOrderSchedule.joins(:standing_order).includes(:order)
      .where("visible = true and (deliver_at >= ? or remind_at >= ? or create_at >= ? or process_at >= ?)", date, date, date, date)
      .where('spree_standing_orders.vendor_id = ?', @vendor.id)
      .ransack(params[:q])

    # @vendor.sales_standing_order_schedules.where("visible = true and (deliver_at >= ? or remind_at >= ? or create_at >= ? or process_at >= ?)", date, date, date, date).ransack(params[:q])
    @search.sorts = 'deliver_at asc' if @search.sorts.empty?
    @schedules = @search.result.page(params[:page])

    if params.fetch(:q, {}).fetch(:deliver_at_gteq, nil).present?
      params[:q][:deliver_at_gteq] = date_start
    end
    if params.fetch(:q, {}).fetch(:deliver_at_lteq, nil).present?
      params[:q][:deliver_at_lteq] = date_end
    end

    revert_ransack_date_to_view(:deliver_at_gteq, @vendor)
    revert_ransack_date_to_view(:deliver_at_lteq, @vendor)

    respond_with(:manage, @order, @schedules)
  end

  def skip
    resp = {}
    if request.put?
      @order = Spree::StandingOrder.find(params[:standing_order_id])
      @schedule = @order.standing_order_schedules.find(params[:standing_order_schedule_id])
      @schedule.skip = true
      @schedule.save
      resp[:success] = "Standing Order #{@order.name} at #{DateHelper.sweet_date(@schedule.deliver_at, @order.vendor.time_zone)} will be skipped!"
    else
      resp[:error] = "Invalid request"
    end

    handle_event(resp)
  end

  def enque
    resp = {}
    if request.put?
      @order = Spree::StandingOrder.find(params[:standing_order_id])
      @schedule = @order.standing_order_schedules.find(params[:standing_order_schedule_id])
      @schedule.skip = false
      @schedule.save
      resp[:success] = "Standing Order #{@order.name} at #{DateHelper.sweet_date(@schedule.deliver_at, @order.vendor.time_zone)} is scheduled!"
    else
      resp[:error] = "Invalid request"
    end

    handle_event(resp)
  end

  def generate_order
    resp = {}
    if request.put?
      @order = Spree::StandingOrder.find(params[:standing_order_id])
      if @order.account.inactive?
        resp[:error] = "This account has been deactivated. You must reactivate it before placing an order."
      else
        @schedule = @order.standing_order_schedules.find(params[:standing_order_schedule_id])
        errors = @schedule.with_lock { @schedule.generate_order! }
        if errors.empty?
          resp[:success] = "Standing Order #{@order.name} at #{DateHelper.sweet_date(@schedule.deliver_at, @order.vendor.time_zone)} has been created!"
        else
          resp[:errors] = errors
        end
      end
    else
      resp[:error] = "Invalid request"
    end

    handle_event(resp)
  end

  def process_order
    resp = {}
    if request.put?
      @order = Spree::StandingOrder.find(params[:standing_order_id])
      @schedule = @order.standing_order_schedules.find(params[:standing_order_schedule_id])
      success = @schedule.with_lock { @schedule.process_order! }
      if success
        resp[:success] = "Standing Order #{@order.name} at #{DateHelper.sweet_date(@schedule.deliver_at, @order.vendor.time_zone)} has been processed!"
      else
        resp[:errors] = @schedule.errors.full_messages
      end
    else
      resp[:error] = "Invalid request"
    end

    handle_event(resp)
  end

  def remind
    resp = {}
    if request.put?
      @order = Spree::StandingOrder.find(params[:standing_order_id])
      @schedule = @order.standing_order_schedules.find(params[:standing_order_schedule_id])
      @schedule.remind!
      resp[:success] = "Standing Order #{@order.name} at #{DateHelper.sweet_date(@schedule.deliver_at, @order.vendor.time_zone)} has been reminded!"
    else
      resp[:error] = "Invalid request"
    end

    handle_event(resp)
  end

  private

  def ensure_write_permission
    if current_spree_user.cannot_write?('standing_orders_schedule', 'standing_orders')
      flash[:error] = 'You do not have permission to view standing order schedules'
      redirect_to manage_path
    end
  end

  def handle_event(resp)
    respond_with do |format|
      format.html do
        flash[:success] = resp[:success]
        flash[:errors] = resp[:errors]
        flash[:error] = resp[:error]
        redirect_to :back
      end
      format.js do
        flash.now[:success] = resp[:success]
        flash.now[:error] = resp[:error]
        flash.now[:errors] = resp[:errors]
        render :update_schedule_line
      end
    end
  end

end
