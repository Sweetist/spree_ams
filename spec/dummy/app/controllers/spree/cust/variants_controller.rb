module Spree
  module Cust

    class VariantsController < Spree::Cust::CustomerHomeController
      before_action :ensure_user_has_accounts
      before_action :set_current_vendor, only: :show
      before_action :clear_current_order, unless: :order_can_add_products?, only: :show
      before_action :ensure_vendor_order_match, only: :show
      before_action :ensure_vendor_products_current_order, only: :show
      respond_to :js

      def show
        @product = @vendor.products.friendly.find(params[:product_id])
        @variant = @product.variants_including_master.find(params[:id])
        @avv = @current_vendor_account.account_viewable_variants
                                      .where(variant_id: @variant.id)
                                      .first

        if @vendor.try(:cva).try(:product_prev_next_show)
          get_previous_and_next
        end

        render :show
      end

      def similar_products
        account = Spree::Account.find(params[:account_id])
        @vendor = current_spree_user.vendors.friendly.find(params[:vendor_id])
        @product = @vendor.products.friendly.find(params[:product_id])
        @variant = @product.variants_including_master.find(params[:id])
        @similar_products = content_for_similar_products(account)
        respond_to do |format|
          format.js
        end
      end

      private

      def get_previous_and_next
        params[:filter] ||= {}
        if params[:filter][:variant_product_taxons_id_or_variant_taxons_id_in].present?
          params[:filter][:variant_product_taxons_id_or_variant_taxons_id_in] = params[:filter][:variant_product_taxons_id_or_variant_taxons_id_in].split(/ /).flatten
        end
        params[:filter][:variant_product_available_on_lt] = Time.current
        @next_prev_params = params[:filter]
        params[:filter] = nil
        current_avv_index = current_vendor.index_of_avv(@avv, @next_prev_params)
        @prev_variant = @vendor.prev_avv(@avv, current_avv_index, @next_prev_params).try(:variant)
        @next_variant = @vendor.next_avv(@avv, current_avv_index, @next_prev_params).try(:variant)
      end

      def set_current_vendor
        @vendor = spree_current_user.vendors.find_by(custom_domain: request.host)
        @vendor ||= spree_current_user.vendors.friendly.find(params[:vendor_id]) rescue nil
        session[:vendor_id] = @vendor.try(:id)
        if @vendor.nil?
          flash[:error] = "You do not have access to view the requested page."
          clear_current_vendor_account
          redirect_to orders_path
        else
          @vendor
        end
      end

      def ensure_vendor_order_match
        unless current_order && current_vendor && current_order.vendor_id == current_vendor.id
          clear_current_order
        end
      end

      def ensure_vendor_products_current_order
        @vendor = current_spree_user.vendors.friendly.find(params[:vendor_id])
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
        @current_vendor_account ||= current_spree_user.vendor_accounts.where(vendor_id: @vendor.id).first
        @current_vendor_account ||= current_spree_user.vendor_accounts.first
        session[:vendor_account_id] = @current_vendor_account.try(:id)

        if @vendor && @current_vendor_account && (@vendor.try(:id) != current_order.try(:vendor_id))
          @current_order = @current_vendor_account.orders.where(state: 'cart').order('created_at desc').first
          @current_order ||= @current_vendor_account.orders.create(
            vendor_id: @vendor.id,
            delivery_date: @current_vendor_account.next_available_delivery_date
          )
          session[:order_id] = @current_order.try(:id)

          associate_user(@current_order)
          @current_order.set_shipping_method
          @current_order.save
        else
          redirect_to new_order_path && return
        end
      end

      def content_for_similar_products(account)
        if current_vendor_variant_nest_name?
          @products = @vendor.products
                             .joins(:account_viewable_variants)
                             .where('spree_account_viewable_variants.visible = ?', true)
                             .where('spree_account_viewable_variants.variant_id IN (?)', account.vendor.variants_for_sale.ids)
                             .where('spree_account_viewable_variants.account_id = ?', account.id)
                             .distinct
          @products.in_taxons(@variant.all_taxons).where.not(id: @product.id)
        else
          avvs = account.account_viewable_variants
                        .where(variant_id: account.vendor.variants_for_sale.ids)
                        .visible
                        .where.not(variant_id: @variant.id)
          taxons_ids = @variant.all_taxons.pluck(:id)
          avvs_pr_taxons = avvs.joins(variant: [product: :taxons])
                               .where('spree_taxons.id IN (?)', taxons_ids)
          avvs_vr_taxons = avvs.joins(variant: :taxons)
                               .where('spree_taxons.id IN (?)', taxons_ids)
          (avvs_vr_taxons + avvs_pr_taxons).distinct
        end
      end
    end
  end
end
