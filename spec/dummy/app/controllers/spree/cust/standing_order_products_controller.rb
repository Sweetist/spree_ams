class Spree::Cust::StandingOrderProductsController < Spree::Cust::CustomerHomeController


  helper_method :sort_column, :sort_direction
  before_action :clear_current_order, only: [:new, :create]
  before_action :ensure_customer

  def index
    @customer = current_customer
    @order = current_customer.purchase_standing_orders.find(params[:standing_order_id])
    @account = @order.account
    @vendor = @order.vendor
    params[:q] ||= {}
    params[:q][:variant_product_available_on_lt] = Time.current
    @search = @account.account_viewable_variants
                  .where(variant_id: @account.vendor.variants_for_sale.ids)
                  .visible
                  .includes(variant: [:product, :prices]).ransack(params[:q])
    params[:q][:variant_product_available_on_lt] = nil

    if current_vendor_variant_nest_name?
      @search.sorts = @vendor.cva.try(:associated_default_sort, :variant, :variant) if @search.sorts.empty?
    else
      @search.sorts = @vendor.cva.try(:associated_default_sort, :flat_variant, :variant) if @search.sorts.empty?
    end
    @user_is_viewing_images = @vendor.cva.try(:catalog_show_images) && current_spree_user.view_images?
    @account_viewable_variants = @search.result.page(params[:page])

    render :index
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
          flash.now[:error] = error
          redirect_to :back
        end
        format.js {flash.now[:error] = error}
      else
        format.html do
          flash[:success] = "Your order has been updated!"
          redirect_to edit_standing_order_path(@order)
        end
        format.js { flash.now[:success] = "Your order has been updated!"}
      end
    end
  end

  def show
    @customer = current_customer
    @order = current_customer.purchase_standing_orders.find(params[:standing_order_id])
    @vendor = @order.vendor
    @account = @order.account
    @product = @vendor.products.friendly.find(params[:id])
    @variants = @product.has_variants? ? @product.variants : @product.variants_including_master.where(is_master: true)
    @avvs = @account.account_viewable_variants
            .where(variant_id: @variants.ids)
            .visible
            .includes(:variant)
    @avv = @avvs.first
  end

  def destroy
    order = Spree::StandingOrder.find(params[:standing_order_id])
    order.start_tracking!
    item = order.standing_line_items.find(params[:item_id])
    item.destroy!
    redirect_to edit_standing_order_path(order), flash: { success: "Item has been removed from your order" }
  end

  private

  def ensure_customer
    @order = Spree::StandingOrder.find(params[:standing_order_id])
    unless current_spree_user.vendor_accounts.find_by_id(@order.try(:account_id)).present?
      flash[:error] = "You don't have permission to view the requested page"
      redirect_to root_url
    end
  end
end
