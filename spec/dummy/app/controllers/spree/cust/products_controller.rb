module Spree
 module Cust
  class ProductsController < Spree::Cust::CustomerHomeController

    before_action :ensure_user_has_accounts
    before_action :set_current_vendor, only: [:index, :show]
    before_action :clear_current_order, unless: :order_can_add_products?, only: [:index, :show]
    before_action :ensure_vendor_order_match, only: [:index, :show]
    before_action :ensure_vendor_products_current_order, only: [:index, :show]

    def index
      params[:q] ||= {}

      @line_items = @current_order.line_items if @current_order

      params[:q][:variant_product_available_on_lt] = Time.current
      if params[:q][:variant_product_taxons_id_or_variant_taxons_id_in].present?
        params[:q][:variant_product_taxons_id_or_variant_taxons_id_in] = params[:q][:variant_product_taxons_id_or_variant_taxons_id_in].split(/ /).flatten
      end
      if session[:vendor_account_id].nil?
        @current_vendor_account = current_spree_user.vendor_accounts.where(vendor_id: @vendor.id).first
        @current_vendor_account ||= current_spree_user.vendor_accounts.first
        params[:q][:account_id_eq] = @current_vendor_account.try(:id)
      else
        params[:q][:account_id_eq] = session[:vendor_account_id]
      end

      @recent_orders = @current_vendor_account.orders.where('completed_at IS NOT NULL').order('completed_at DESC').limit(5)
      @search = @current_vendor_account.account_viewable_variants
                        .where(variant_id: @current_vendor_account.vendor.variants_for_sale.ids)
                        .visible
                        .includes(variant: [:images, :prices, product: [:variant_images], stock_items: [:stock_location]])
                        .ransack(params[:q])
      params[:q][:variant_product_available_on_lt] = nil
      @vendor = current_vendor
      if current_vendor_variant_nest_name?
        @search.sorts = @vendor.cva.try(:associated_default_sort, :variant, :variant) if @search.sorts.empty?
      else
        @search.sorts = @vendor.cva.try(:associated_default_sort, :flat_variant, :variant) if @search.sorts.empty?
      end
      @user_is_viewing_images = @vendor.cva.try(:catalog_show_images) && current_spree_user.view_images?
      @account_viewable_variants = @search.result
                                          .page(params[:page])
                                          .per(params[:per_page] || @vendor.cva.catalog_products_per_page)
      @hide_logo = @vendor.try(:cva).try(:hide_logo, 'catalog')
      @hide_search_bar = !@vendor.try(:cva).try(:catalog_search_bar)
      @taxonomies = @vendor.taxonomies.includes(:taxons)
      @pages_header = @vendor.pages.header_links
      @pages_footer = @vendor.pages.footer_links
      render :index
    end

    def show
      @product = @vendor.products.friendly.find(params[:id])

      # @variants should be an ActiveRecord Relation
      @variants = @product.has_variants? ? @product.variants : @product.variants_including_master.where(is_master: true)

      @avvs = @current_vendor_account.account_viewable_variants
                .joins(:variant)
                .where(variant_id: @variants.ids, account_id: @current_vendor_account.id)
                .where('spree_variants.discontinued_on is null')
                .visible
      render :show
    end

    def update_customized_pricing
      @avv = Spree::AccountViewableVariant.find_by_id(params[:avv_id])
      @vendor = @avv.try(:variant).try(:vendor)
      @avv.try(:cache_price)
      respond_to do |format|
        format.html {redirect_to :back}
        format.js {}
      end
    end

    private

    def set_current_vendor
      @vendor = spree_current_user.vendors.find_by(custom_domain: request.host)
      @vendor ||= spree_current_user.vendors.friendly.find(params[:vendor_id]) rescue nil
      session[:vendor_id] = @vendor.try(:id)
      if @vendor.nil?
        flash[:error] = "You do not have access to view the requested page."
        clear_current_vendor_account
        redirect_to orders_path
      else
        if ![@vendor.slug, @vendor.id.to_s].include? params[:vendor_id].to_s
          redirect_to vendor_products_url(@vendor)
        end
        @vendor
      end
    end

    def ensure_vendor_order_match
      unless current_order && current_vendor && current_order.vendor_id == current_vendor.id
        clear_current_order
      end
    end

    def ensure_vendor_products_current_order
      @vendor ||= current_spree_user.vendors.friendly.find(params[:vendor_id])
      session[:vendor_id] = @vendor.try(:id)
      #switch between accounts for same vendor
      if params.fetch(:q, {}).fetch(:account_id_eq, nil).to_i != 0
        #update session vendor_account_id
        session[:vendor_account_id] = params[:q][:account_id_eq]
        params[:q][:account_id_eq] = nil
      end

      if session[:vendor_account_id]
        @current_vendor_account = current_spree_user.vendor_accounts.where(
          vendor_id: @vendor.id, id: session[:vendor_account_id]
        ).first
      end
      @current_vendor_account ||= current_spree_user.vendor_accounts.where(vendor_id: @vendor.try(:id)).first
      @current_vendor_account ||= current_spree_user.vendor_accounts.first
      session[:vendor_account_id] = @current_vendor_account.try(:id)

      if @vendor && @current_vendor_account \
        && (@vendor.try(:id) != current_order.try(:vendor_id) \
        || (@current_vendor_account.id != current_order.try(:account_id)))
        @current_order = @current_vendor_account.orders.where(state: 'cart').order('created_at desc').first
        @current_order ||= @current_vendor_account.orders.create(
          vendor_id: @vendor.id,
          delivery_date: @current_vendor_account.next_available_delivery_date
        )
        session[:order_id] = @current_order.try(:id)

        associate_user(@current_order)
        @current_order.txn_class_id = @current_vendor_account.default_txn_class_id if @vendor.track_order_class?
        @current_order.set_shipping_method
        @current_order.save
      else
        redirect_to new_order_path && return
      end

    end
  end
 end
end
