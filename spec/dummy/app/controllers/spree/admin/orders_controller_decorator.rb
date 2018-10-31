Spree::Admin::OrdersController.class_eval do

  def delivery_update
    @order = Spree::Order.find_by(:number => params[:id])
    if params[:order][:delivery_date].blank?
      flash[:error] = "Order must have a delivery/ship date."
    else
      @order.update_attribute(:delivery_date, params[:order][:delivery_date])
    end
    redirect_to :back
  end

  def new
    @order = Spree::Order.create(order_params)
    redirect_to cart_admin_order_url(@order)
  end

  #
  private
  def order_params
    params[:created_by_id] = try_spree_current_user.try(:id)
    params[:delivery_date] ||= Time.current + 1.days
    params.permit(:customer_id, :delivery_date,
      :user_id, :created_by_id)
  end

end
