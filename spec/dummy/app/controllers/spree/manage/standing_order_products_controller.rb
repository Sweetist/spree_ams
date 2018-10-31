class Spree::Manage::StandingOrderProductsController < Spree::Manage::BaseController

  before_action :clear_current_order, only: [:new, :create]

  before_action :ensure_write_permission

  def index
    @vendor = current_vendor
    @current_order = current_vendor.sales_standing_orders.find(params[:standing_order_id])

    session[:account_id] = @current_order.account.id
    session[:account_show_all] = params[:account_show_all]
    @user_is_viewing_images = current_spree_user.view_images?

    @account = @current_order.account
    params[:q] ||= {}
    @open_search = params[:q].except('s').any?{|k,v| v.present?}
    if @open_search
      session[:account_show_all] = params[:product_list].blank? ? 'true' : params[:product_list]
    else
      session[:account_show_all] = params[:account_show_all]
    end

    filter_avvs

    render :index
  end

  def filter_avvs
    if params.fetch(:q, {}).fetch(:include_inactive, '0').to_bool
      @search = @account.account_viewable_variants
                        .where(variant_id: @account.vendor.variants_for_sale_with_inactive.ids)
                        .includes(variant: [:product, :prices])
    else
      @search = @account.account_viewable_variants
                        .where(variant_id: @account.vendor.variants_for_sale.ids)
                        .includes(variant: [:product, :prices])
    end
    if session[:account_show_all] != "true" && params.fetch(:q, {}).fetch(:include_unavailable, false) == '1'
      params[:q][:include_unavailable] = true
      params[:q][:variant_product_available_on_lt] = nil
      @search = @search.visible.ransack(params[:q])
    elsif session[:account_show_all] != "true"
      params[:q][:variant_product_available_on_lt] = Time.current
      @search = @search.visible.ransack(params[:q])
    elsif params.fetch(:q, {}).fetch(:include_unavailable, false) == '1'
      params[:q][:include_unavailable] = true
      params[:q][:variant_product_available_on_lt] = nil
      @search = @search.ransack(params[:q])
    else
      params[:q][:variant_product_available_on_lt] = Time.current
      @search = @search.ransack(params[:q])
    end

    @search.sorts = @vendor.cva.try(:associated_default_sort, :variant, :variant) if @search.sorts.empty?
    @account_viewable_variants = @search.result.page(params[:page])
  end

  def create
    @order = Spree::StandingOrder.find(params[:standing_order_id])
    @order.start_tracking!
    error = nil

    if params[:standing_order] && params[:standing_order][:products]
			variants = params[:standing_order][:products].keep_if do |id, qty|
				qty.to_f.between?(0.00001, 2_147_483_647)
			end

      if variants.empty?
        error = "No products were selected"
      else
        @order.add_many(variants, {})
      end
		end

    respond_with(@order) do |format|
      if error
        format.html do
          flash[:error] = error
          redirect_to :back
        end
        format.js {flash.now[:error] = error}
      else
        format.html do
          flash[:success] = "Your order has been updated!"
          redirect_to edit_manage_standing_order_path(@order)
        end
        format.js { flash.now[:success] = "Your order has been updated!"}
      end
    end
  end

  def show
    # @vendor = current_vendor
    # @current_order = current_vendor.sales_standing_orders.find(params[:standing_order_id])
    # @product = current_vendor.products.friendly.find(params[:id])
    # @account = @current_order.account
    # @variants = @product.has_variants? ? @product.variants : @product.variants_including_master.where(is_master: true)
    # @avvs = @account.account_viewable_variants.where(variant_id: @variants.ids)
    # @avv = @avvs.first

    redirect_to edit_manage_product_url
  end

  def destroy
    order = Spree::StandingOrder.find(params[:standing_order_id])
    order.start_tracking!
    item = order.standing_line_items.find(params[:item_id])
    item.destroy!
    redirect_to edit_manage_standing_order_path(order), flash: { success: "Item has been removed from your order" }
  end

  private

  def ensure_write_permission
    if current_spree_user.cannot_read?('basic_options', 'standing_orders')
      flash[:error] = 'You do not have permission to view standing orders'
      redirect_to manage_path
    elsif current_spree_user.cannot_write?('basic_options', 'standing_orders')
      flash[:error] = 'You do not have permission to edit standing orders'
      redirect_to manage_standing_orders_path
    end
  end
end
