class Spree::Cust::StandingOrderSchedulesController < Spree::Cust::CustomerHomeController
  helper_method :sort_column, :sort_direction

  def index
    @customer = current_customer
    date = Date.current
    @search = @customer.purchase_standing_order_schedules.where("visible = true and (deliver_at >= ? or remind_at >= ? or create_at >= ? or process_at >= ?)", date, date, date, date).ransack(params[:q])
    @search.sorts = 'deliver_at asc' if @search.sorts.empty?
    @schedules = @search.result.page(params[:page])

    respond_with(:cust, @order, @schedules)
  end

  def skip
    if request.put?
      @order = Spree::StandingOrder.find(params[:standing_order_id])
      schedule = @order.standing_order_schedules.find(params[:standing_order_schedule_id])
      schedule.skip = true
      schedule.save
      redirect_to :back, flash: { success: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} will be skipped!" }
    else
      redirect_to :back, flash: { error: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} cannot be enqueued!" }
    end
  end

  def enque
    if request.put?
      @order = Spree::StandingOrder.find(params[:standing_order_id])
      schedule = @order.standing_order_schedules.find(params[:standing_order_schedule_id])
      schedule.skip = false
      schedule.save
      redirect_to :back, flash: { success: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} is scheduled!" }
    else
      redirect_to :back, flash: { error: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} cannot be skipped!" }
    end
  end

  def generate_order
    if request.put?
      @order = Spree::StandingOrder.find(params[:standing_order_id])
      schedule = @order.standing_order_schedules.find(params[:standing_order_schedule_id])
      schedule.generate_order!
      redirect_to :back, flash: { success: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} has been created!" }
    else
      redirect_to :back, flash: { error: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} cannot be created!" }
    end
  end

  def process_order
    if request.put?
      @order = Spree::StandingOrder.find(params[:standing_order_id])
      schedule = @order.standing_order_schedules.find(params[:standing_order_schedule_id])
      schedule.process_order!
      redirect_to :back, flash: { success: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} has been processed!" }
    else
      redirect_to :back, flash: { error: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} cannot be processed!" }
    end
  end

  def remind
    if request.put?
      @order = Spree::StandingOrder.find(params[:standing_order_id])
      schedule = @order.standing_order_schedules.find(params[:standing_order_schedule_id])
      schedule.remind!
      redirect_to :back, flash: { success: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} has been reminded!" }
    else
      redirect_to :back, flash: { error: "Standing Order #{@order.name} at #{DateHelper.sweet_date(schedule.deliver_at, schedule.standing_order.vendor.time_zone)} cannot be reminded!" }
    end
  end



end
