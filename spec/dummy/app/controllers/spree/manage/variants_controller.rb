module Spree
  module Manage

    class VariantsController < Spree::Manage::BaseController
      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy, :add_part_to_assembly, :load_parts_variants]
      before_action :load_product, except: [:add_part_to_assembly, :load_parts_variants]
      before_action :warn_product_ordered, only: [:new, :create]
      before_action :warn_qbo_categories, only: [:new, :create]
      before_action :clear_current_order, unless: :order_can_add_products?, only: [:index, :show]
      before_action :ensure_read_permission, only: [:show, :edit, :index]
      before_action :ensure_write_permission, only: [:new, :update, :create]
      before_action :ensure_subscription_limit, only: [:new, :create]
      respond_to :js

      def new
        @variant = @product.new_from_master
        respond_to do |format|
          format.html { render :new }
          format.js {}
        end
      end

      def create
        params[:variant] ||= {}
        params[:variant][:vendor_account_ids] ||= []
        unless variant_params[:vendor_account_ids].include? variant_params[:preferred_vendor_account_id]
          params[:variant][:vendor_account_ids] << variant_params[:preferred_vendor_account_id]
        end
        @variant = @product.variants.new(variant_params)
        if @variant.save
          flash[:success] = 'Variant saved.'
          respond_to do |format|
            format.html do
              redirect_to edit_manage_product_variant_path(@product, @variant)
            end
            format.js do
              render js: "window.location.reload();"
            end
          end
        else
          flash.now[:errors] = @variant.errors.full_messages
          respond_to do |format|
            format.html do
              render :new
            end
            format.js do
              render :new
            end
          end
        end
      end

      def show
        redirect_to edit_manage_product_variant_path
        # @variant = @product.variants_including_master.find(params[:id])
        #
        # @vendor = current_vendor
        # @current_order = current_order
        #
        # if params[:standing_order_id]
        #   @current_order = @vendor.sales_standing_orders.find(params[:standing_order_id])
        # end
        #
        #
        # if @current_order
        #   @account = @current_order.account
        # else
        #   unless params[:account_id].nil?
        #     if params[:account_id] == '0'
        #       clear_current_account
        #     else
        #       session[:account_id] = params[:account_id]
        #       session[:account_show_all] = params[:account_show_all]
        #     end
        #   end
        #   @account = current_account
        # end
        # @avv = @variant.account_viewable_variants.find_by(account_id: @account.try(:id)) if @account
        #
        # respond_to do |format|
        #   format.html { render :show }
        #   format.js { render :show }
        # end
      end

      def edit
        @variant = @product.variants_including_master.find(params[:id])
        respond_to do |format|
          format.html { render :edit }
          format.js { render :edit }
        end
      end

      def update
        @variant = @product.variants_including_master.find(params[:id])
        params[:variant] ||= {}
        params[:variant][:vendor_account_ids] ||= []
        unless variant_params[:vendor_account_ids].include? variant_params[:preferred_vendor_account_id]
          params[:variant][:vendor_account_ids] << variant_params[:preferred_vendor_account_id]
        end
        
        if @variant.update(variant_params)
          flash[:success] = 'Variant saved.'
          respond_to do |format|
            format.html do
              redirect_to manage_product_variant_path(@product, @variant)
            end
            format.js do
              render js: "window.location.reload();"
            end
          end
        else
          flash.now[:errors] = @variant.errors.full_messages
          respond_to do |format|
            format.html do
              render :edit
            end
            format.js do
              render :edit
            end
          end
        end
      end

      def discontinue
        @variant = @product.variants_including_master.find(params[:id])

        if @variant.is_master?
          unless @product.discontinue
            flash[:errors] = @product.errors.full_messages
          end
        else
          unless @variant.discontinue
            flash[:errors] = @variant.errors.full_messages
          end
        end

        respond_to do |format|
          format.js {render js: "window.location.reload();"}
          format.html {redirect_to :back}
        end
      end

      def make_available
        @variant = @product.variants_including_master.find(params[:id])
        if @variant.is_master?
          @product.make_available
        else
          @variant.make_available
        end

        respond_to do |format|
          format.js {render js: "window.location.reload();"}
          format.html {redirect_to :back}
        end
      end

      def add_part_to_assembly
        # This method only builds the part relationship, it does not save it
        @part_variant = @variant.parts_variants.find_or_initialize_by(part_id: params[:part_id])
        @part_variant.count = params[:qty_to_add]
        respond_to do |format|
          format.js {}
        end
      end

      def load_parts_variants
        @parts_variants = @variant.parts_variants.includes(:assembly, :part)
        @sub_product_ids = {}
        @stock_location_variant_count = {}
        @parts_variants.each do |part|
          @sub_product_ids[part.part_id] = part.count
          variant_of_part = part.part
          stock_location = {}
          if variant_of_part.should_track_lots?
            variant_of_part.stock_item_lots.each do |stock_item_lot|
              stock_location[stock_item_lot.id] = stock_item_lot.count
            end
          else
            @vendor.stock_locations.each do |location|
              stock_location[location.id] = location.count_on_hand(variant_of_part)
            end
          end
          @stock_location_variant_count[part.part.id] = stock_location
        end
        @sub_product_ids = @sub_product_ids.to_json.html_safe
        @stock_location_variant_count = @stock_location_variant_count.to_json.html_safe
        respond_to do |format|
          format.js {}
        end
      end

      def toggle_lot_tracking
        @variant = @product.variants_including_master.find(params[:id])
        @variant.update_column :lot_tracking, params[:lot_tracking]

        render nothing: true
      end

      private

      def variant_params
        params.require(:variant).permit(
          :sku, :price, :variant_description, :pack_size, :pack_size_qty, :lead_time, :id, :is_master, :track_inventory, :lot_tracking, :visible_to_all, :display_name,
          :cost_price, :minimum_order_quantity, :incremental_order_quantity, :cost_currency, :weight, :weight_units, :width, :height, :depth, :dimension_units, :tax_category_id,
          :general_account_id, :income_account_id, :cogs_account_id, :asset_account_id, :expense_account_id, :variant_type, :txn_class_id,
          :sweetist_lead_time_hours, :sweetist_fragile, :sweetist_dietary_info, :sweetist_max_order_qty, :sweetist_num_servings,
          :costing_method, :avg_cost_price, :last_cost_price, :sum_cost_price,
          :preferred_vendor_account_id,
          :active,
          :text_options,
          parts_variants_attributes: [:id, :assembly_id, :part_id, :count, :_destroy],
          option_value_ids: [],
          stock_items_attributes: [:id, :backorderable, :min_stock_level],
          variant_price_lists_attributes: [:id, :price, :_destroy],
          prices_attributes: [:id, :amount],
          taxon_ids: [],
          vendor_account_ids: []
        )
      end

      def ensure_vendor
        @vendor = current_vendor
        @variant = Spree::Variant.find(params[:id])
        @product = @variant.product
        unless @vendor.id == @product.vendor_id
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to root_url
        end
      end

      def load_product
        @vendor ||= current_vendor
        @product ||= @vendor.products.friendly.find(params[:product_id]) rescue nil
      end

      def warn_product_ordered
        @warn_product_ordered = true
        @warn_product_ordered = false if @product.has_variants?
        @warn_product_ordered = false if @product.master.line_items.none?
      end

      def warn_qbo_categories
        @warn_qbo_categories = current_vendor.integration_items
          .where(integration_key: 'qbo').any? do |integration|
            integration.try(:qbo_use_categories)
          end
      end

      def ensure_vendor_order(vendor_id, order_vendor_id)
        unless vendor_id == order_vendor_id
          clear_current_order
          redirect_to manage_products_path
        end
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('catalog', 'products')
          flash[:error] = 'You do not have permission to view products'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('catalog', 'products')
          flash[:error] = 'You do not have permission to view products'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('catalog', 'products')
          flash[:error] = 'You do not have permission to edit products'
          redirect_to manage_products_path
        end
      end

      def ensure_subscription_limit
        product_limit = current_company.subscription_limit('products')
        unless current_company.within_subscription_limit?('products', current_company.showable_variants.active.count)
          respond_to do |format|
            format.html do
              flash[:error] = "Your subscription is limited to #{product_limit} #{'product'.pluralize(product_limit)}."
              redirect_to manage_products_path
            end
            format.js do
              flash[:error] = "Your subscription is limited to #{product_limit} #{'product'.pluralize(product_limit)}."
              render js: "window.location.reload();"
            end
          end
        end
      end

    end
  end
end
