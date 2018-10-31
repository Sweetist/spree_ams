module Spree
  module Manage

    class ProductsController < Spree::Manage::BaseController

      helper_method :sort_column, :sort_direction
      before_action :load_assemblies_parts, only: [:show, :edit]
      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :clear_current_order, unless: :order_can_add_products?, only: [:index, :show]
      before_action :ensure_read_permission, only: [:show, :edit, :index]
      before_action :ensure_write_permission, only: [:new, :update, :create, :actions_router]
      before_action :ensure_subscription_limit, only: [:new, :create]
      respond_to :js
      def index
        @vendor = current_vendor
        @vendor_has_variants = @vendor.variants.any?
        @current_order = current_order
        if params[:standing_order_id]
          @current_order = @vendor.sales_standing_orders.find(params[:standing_order_id])
        end
        @account = @current_order ? @current_order.account : nil
        @categories = @vendor.taxons.where.not(parent_id: nil).order(:name)
        @user_is_viewing_images = current_spree_user.view_images?
        params[:q] ||= {}
        params[:account_id] = session[:account_id] if params[:account_id].blank?
        @open_search = params[:q].except('s').any?{|k,v| v.present?}
        if @current_order
          ensure_vendor_order(@vendor.id, @current_order.vendor_id)
          session[:account_id] = @current_order.account.id
          if @open_search
            session[:account_show_all] = params[:product_list].blank? ? 'true' : params[:product_list]
          else
            session[:account_show_all] = params[:account_show_all]
          end
        elsif params[:account_id].blank? || params[:account_id] == '0'
          clear_current_account
        else
          if @open_search
            session[:account_show_all] = params[:product_list].blank? ? 'true' : params[:product_list]
          else
            session[:account_show_all] = params[:account_show_all]
          end
          session[:account_id] = params[:account_id]
        end
        @current_account = current_account

        @use_full_name = params[:q][:s].present? && !params[:q][:s].include?('name')
        if session[:account_id].blank?
          switch_params_avv_to_variant
          products_with_variants_ids = Spree::Product.joins(:variants).distinct.ids
          if params.fetch(:q, {}).fetch(:include_unavailable, '1').to_bool
            params[:q][:include_unavailable] = true
            unless products_with_variants_ids.empty?
              @search = Spree::Variant.joins(:product).where('spree_products.vendor_id = ?',@vendor.id)
                                                      .where('(spree_variants.is_master = ? and spree_variants.product_id in (?)) or (spree_variants.is_master = ? and spree_variants.product_id not in (?))',
                                                              false, products_with_variants_ids, true, products_with_variants_ids)
                                                      .includes(:prices, stock_items: :stock_location)
            else
              @search = Spree::Variant.joins(:product).where('spree_products.vendor_id = ?',@vendor.id)
                                                      .includes(:prices, stock_items: :stock_location)
            end
          else
            params[:q][:include_unavailable] = false
            unless products_with_variants_ids.empty?
              @search = Spree::Variant.joins(:product).where('spree_products.vendor_id = ?',@vendor.id)
                                                      .where('(spree_variants.is_master = ? and spree_variants.product_id in (?)) or (spree_variants.is_master = ? and spree_variants.product_id not in (?))',
                                                              false, products_with_variants_ids, true, products_with_variants_ids)
                                                      .where("spree_products.available_on <= ?", Time.current)
                                                      .includes(:prices, stock_items: :stock_location)
            else
              @search = Spree::Variant.joins(:product).where('spree_products.vendor_id = ?',@vendor.id)
                                                      .where("spree_products.available_on <= ?", Time.current)
                                                      .includes(:prices, stock_items: :stock_location)
            end
          end
          unless params.fetch(:q, {}).fetch(:include_inactive, '0').to_bool
            @search = @search.active
          end
          @search = @search.ransack(params[:q])
          @search.sorts = @vendor.cva.try(:variant_default_sort) if @search.sorts.empty?
          @variants = @search.result.page(params[:page])
          render :index
        elsif @current_order
          @account = @current_order.account
          filter_avvs
          render :current_order_index
        else
          @account = session[:account_id] ? @vendor.customer_accounts.find(session[:account_id]) : nil
          filter_avvs
          render :account_viewable_variant_index
        end
      end

      def filter_avvs
        switch_params_variant_to_avv
        if params.fetch(:q, {}).fetch(:include_inactive, '0').to_bool
          @search = @account.account_viewable_variants
                            .where(variant_id: @account.vendor.variants_for_sale_with_inactive.ids)
                            .includes(variant: [:product, :prices])
        else
          @search = @account.account_viewable_variants
                            .where(variant_id: @account.vendor.variants_for_sale.ids)
                            .includes(variant: [:product, :prices])
        end
        if session[:account_show_all] != "true" && params.fetch(:q, {}).fetch(:include_unavailable, false).to_bool
          params[:q][:include_unavailable] = true
          params[:q][:variant_product_available_on_lt] = nil
          @search = @search.visible.ransack(params[:q])
        elsif session[:account_show_all] != "true"
          params[:q][:variant_product_available_on_lt] = Time.current
          @search = @search.visible.ransack(params[:q])
        elsif params.fetch(:q, {}).fetch(:include_unavailable, false).to_bool
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

      def switch_params_variant_to_avv
        # transfer search params from products search unless already searching on avvs
        params[:q][:variant_full_display_name_or_variant_sku_cont] ||= params[:q][:full_display_name_or_sku_cont]
        params[:q][:variant_full_display_name_cont] ||= params[:q][:full_display_name_cont]
        params[:q][:variant_sku_cont] ||= params[:q][:sku_cont]
        params[:q][:variant_product_taxons_id_or_variant_taxons_id_in] ||= params[:q][:taxons_id_or_product_taxons_id_in]
        params[:q][:variant_product_available_on_lt] = params[:q][:product_available_on_lt]
        params[:q][:variant_product_for_sale_eq] = true
        params[:q][:variant_product_can_be_part_true] ||= params[:q][:product_can_be_part_true]

        # Set params from product search to nil so they are not used
        params[:q][:full_display_name_or_sku_cont] = nil
        params[:q][:full_display_name_cont] = nil
        params[:q][:sku_cont] = nil
        params[:q][:taxons_id_or_product_taxons_id_in] = nil
        params[:q][:discontinued_on_null] = nil
        params[:q][:product_available_on_lt] = nil
        params[:q][:product_can_be_part_true] = nil
      end

      def switch_params_avv_to_variant
        # transfer search params from avv search unless already searching on products
        params[:q][:full_display_name_or_sku_cont] ||= params[:q][:variant_full_display_name_or_variant_sku_cont]
        params[:q][:full_display_name_cont] ||= params[:q][:variant_full_display_name_cont]
        params[:q][:sku_cont] ||= params[:q][:variant_sku_cont]
        params[:q][:taxons_id_or_product_taxons_id_in] ||= params[:q][:variant_product_taxons_id_or_variant_taxons_id_in]
        params[:q][:product_available_on_lt] ||= params[:q][:variant_product_available_on_lt]
        params[:q][:product_can_be_part_true] ||= params[:q][:variant_product_can_be_part_true]

        # Set params from avv search to nil so they are not used
        params[:q][:variant_full_display_name_or_variant_sku_cont] = nil
        params[:q][:variant_full_display_name_cont] = nil
        params[:q][:variant_sku_cont] = nil
        params[:q][:variant_product_taxons_id_or_variant_taxons_id_in] = nil
        params[:q][:variant_product_available_on_lt] = nil
        params[:q][:variant_product_for_sale_eq] = nil
        params[:q][:variant_product_can_be_part_true] = nil
      end

      def actions_router
        account_id = params.fetch(:account, {}).fetch(:id, nil)
        if params[:all_variants] == 'true'
          avv_ids = []
          variant_ids = []
        elsif params[:account] && params[:account][:account_viewable_variants_attributes]
          params[:account][:account_viewable_variants_attributes] ||= {}
          avv_ids = params[:account][:account_viewable_variants_attributes].map {|k, v| v[:id] if v[:action].present? && v[:id].present? }.compact
        elsif params[:company] && params[:company][:variants_attributes]
          variant_ids = params[:company][:variants_attributes].map {|k, v| v[:id] if v[:action].present? && v[:id].present? }.compact
        end

        if current_company.try(:set_visibility_by_price_list)
          visibility_actions = [Spree.t(:show_products),
            # Spree.t(:show_products_to_all), #allowing this now
            Spree.t(:hide_products_from_all),
            Spree.t(:hide_products)
          ]
          if visibility_actions.include?(params[:commit])
            flash[:error] = 'Changing product visibility can only be done through price lists.'
            redirect_to :back and return
          end
        end

        case params[:commit]
        when Spree.t(:show_products)
          share_products(account_id, params[:all_variants], avv_ids)
        when Spree.t(:show_products_to_all)
          share_products_with_all_cust(current_vendor, params[:all_variants], variant_ids)
        when Spree.t(:hide_products_from_all)
          hide_products_from_all_cust(current_vendor, params[:all_variants], variant_ids)
        when Spree.t(:hide_products)
          hide_products(account_id, params[:all_variants], avv_ids)
        # when 'Enable Inventory Tracking'
        #   track_inventory(current_vendor, params[:all_variants], true, product_ids)
        # when 'Disable Inventory Tracking'
        #   track_inventory(current_vendor, params[:all_variants], false, product_ids)
        when Spree.t(:enable_backorderable)
          backorderable(current_vendor, params[:all_variants], true, variant_ids)
        when Spree.t(:disable_backorderable)
          backorderable(current_vendor, params[:all_variants], false, variant_ids)
        end

        flash[:success] = 'Products Updated'
        redirect_to :back
      end

      def new
        @vendor = current_vendor
        @product = current_vendor.products.new
        @option_types = @product.option_types.includes(:option_values)
        render :new
      end

      def create
        @vendor = current_vendor
        @user_product_permision = current_spree_user.permission_products_catalog

        format_form_date_field(:product, :available_on, @vendor)

        params[:product] ||= {}
        if params[:product][:master_attributes]
          params[:product][:master_attributes][:vendor_account_ids] ||= []
          unless product_params.fetch(:master_attributes, {}).fetch(:vendor_account_ids, []).include?(product_params.fetch(:master_attributes, {}).fetch(:preferred_vendor_account_id, nil))
            params[:product][:master_attributes][:vendor_account_ids] << product_params.fetch(:master_attributes, {}).fetch(:preferred_vendor_account_id, nil)
          end
        end
        @product = current_vendor.products.new(product_params)

        if @product.save
          flash[:success] = "#{@product.name} has been successfully created and will be available shortly."
          respond_to do |format|
            format.js { render js: "window.location.reload();" }
            format.html { redirect_to edit_manage_product_url(@product) }
            format.json { render json: @product }
          end
        else
          flash.now[:errors] = @product.errors.full_messages
          respond_to do |format|
            format.js { render :new }
            format.html { render :new }
          end
        end

      end

      def show
        redirect_to edit_manage_product_path
        # @vendor = current_vendor
        # @current_order = current_order
        # @variants = @product.has_variants? ? @product.variants : @product.variants_including_master.where(is_master: true)
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
        #
        # if @account
        #   @avvs = @vendor.account_viewable_variants
        #                  .joins(:variant)
        #                  .where(variant_id: @variants.ids, account_id: @account.id)
        #                  .where('spree_variants.discontinued_on is null')
        #   if @avvs.empty?
        #     @avvs = @vendor.account_viewable_variants
        #                    .joins(:variant)
        #                    .where(variant_id: @variants.ids, account_id: @account.id)
        #   end
        #   @avv = @avvs.first
        # end
        # respond_to do |format|
        #   format.js { render :show }
        #   format.html { render :show }
        #   format.json { render json: @product }
        # end
      end

      def edit
        respond_to do |format|
          format.js { render :edit }
          format.html { render :edit }
          format.json { render json: @product }
        end
      end

      def update
        @product = Spree::Product.friendly.find(params[:id])
        @vendor = current_vendor
        format_form_date_field(:product, :available_on, @vendor)
        params[:product] ||= {}
        if params[:product][:master_attributes]
          params[:product][:master_attributes][:vendor_account_ids] ||= []
          unless product_params.fetch(:master_attributes, {}).fetch(:vendor_account_ids, []).include?(product_params.fetch(:master_attributes, {}).fetch(:preferred_vendor_account_id, nil))
            params[:product][:master_attributes][:vendor_account_ids] << product_params.fetch(:master_attributes, {}).fetch(:preferred_vendor_account_id, nil)
          end
        end

        if @product.update(product_params)
          flash[:success] = 'Product has been updated!'
          if params[:commit] == Spree.t('variant.deactivate')
            unless @product.discontinue
              flash.now[:errors] = @product.errors.full_messages
            end
          elsif params[:commit] == Spree.t('variant.make_available')
            unless @product.make_available
              flash[:success] = nil
              flash.now[:errors] = @product.errors.full_messages
            end
          end

          @product.notify_variants

          respond_to do |format|
            if flash[:errors].present?
              format.js { render :edit }
              format.html { render :edit }
            else
              format.js { render js: "window.location.reload();" }
              format.html { redirect_to edit_manage_product_url(@product) }
              format.json { render json: @product }
            end
          end
        else
          # monkey patch fix error duplication
          err = @product.errors.messages.delete(:lot_tracking)
          @product.errors.messages[:base] << err if err.present?
          @product.errors.messages.delete(:'master.lot_tracking')

          flash.now[:errors] = @product.errors.full_messages
          respond_to do |format|
            format.js { render :edit }
            format.html { render :edit }
          end
        end
      end

      def destroy_variant
        if params[:variant_id]
          @variant = Spree::Variant.find(params[:variant_id])
          @product = @variant.product
          unless @variant.is_master
            @variant.destroy!
          else
            flash.now[:error] = "You cannot delete the master variant."
            render :edit
          end
        end

        redirect_to edit_manage_product_url(params[:product_id])
      end

      def share_products(account_id, all_variants, avv_ids = [])
        if all_variants == 'true'
          Spree::AccountViewableVariant.joins(variant: :product)
            .where('spree_products.for_sale = ?', true)
            .where('spree_variants.id IN (?)', current_vendor.showable_variants.ids)
            .where(account_id: account_id, visible: false)
            .update_all(visible: true)
        else
          Spree::AccountViewableVariant.joins(variant: :product)
            .where('spree_products.for_sale = ?', true)
            .where('spree_variants.id IN (?)', current_vendor.showable_variants.ids)
            .where(id: avv_ids, visible: false)
            .update_all(visible: true)
        end
      end

      def share_products_with_all_cust(vendor, all_variants, variant_ids = [])
        if all_variants == 'true'
          vendor.account_viewable_variants.joins(variant: :product)
            .where('spree_products.for_sale = ?', true)
            .where('spree_variants.id IN (?)', vendor.showable_variants.ids)
            .where(visible: false)
            .update_all(visible: true)
          vendor.variants_including_master.update_all(visible_to_all: true)
        else
          vendor.account_viewable_variants.joins(variant: :product)
            .where('spree_products.for_sale = ?', true)
            .where('spree_variants.id IN (?)', vendor.showable_variants.ids)
            .where(variant_id: variant_ids, visible: false)
            .update_all(visible: true)
          vendor.variants_including_master
            .where(id: variant_ids)
            .update_all(visible_to_all: true)
        end
      end

      def hide_products_from_all_cust(vendor, all_variants, variant_ids = [])
        if all_variants == 'true'
          vendor.account_viewable_variants.joins(variant: :product)
            .where('spree_variants.id IN (?)', vendor.showable_variants.ids)
            .where(visible: true)
            .update_all(visible: false)
          vendor.variants_including_master.update_all(visible_to_all: false)
        else
          vendor.account_viewable_variants.joins(variant: :product)
            .where('spree_variants.id IN (?)', vendor.showable_variants.ids)
            .where(variant_id: variant_ids, visible: true)
            .update_all(visible: false)
          vendor.variants_including_master
            .where(id: variant_ids)
            .update_all(visible_to_all: false)
        end
      end

      def hide_products(account_id, all_variants, avv_ids = [])
        if all_variants == 'true'
          current_company.avvs.where(account_id: account_id, visible: true).update_all(visible: false)
          current_company.variants_including_master.update_all(visible_to_all: false)
        else
          current_company.avvs.where(id: avv_ids, visible: true).update_all(visible: false)
          current_company.variants_including_master
            .where(id: current_company.avvs.where(id: avv_ids).pluck(:variant_id))
            .update_all(visible_to_all: false)
        end
      end

      def backorderable(vendor, all_variants, bool, variant_ids = [])
        if all_variants == 'true'
          vendor.stock_items.update_all(backorderable: bool)
        else
          vendor.stock_items.where(variant_id: variant_ids).update_all(backorderable: bool)
        end
      end

      def update_customized_pricing
        @avv = current_vendor.account_viewable_variants.find_by_id(params[:avv_id])
        @avv.cache_price
        @vendor = @avv.try(:product).try(:vendor)
        respond_to do |format|
          format.html { redirect_to :back }
          format.js {}
        end
      end

      def update_all_viewable_variants
        visibility = params[:all_viewable_by] == 'true'
        if visibility
          current_vendor.account_viewable_variants.joins(variant: :product)
            .where('spree_products.for_sale = ?', true)
            .where('spree_variants.id IN (?)', current_vendor.showable_variants.ids)
            .where('account_id = ?', params[:account_id]).update_all(visible: visibility)
        else
          current_vendor.account_viewable_variants.joins(variant: :product)
            .where('spree_products.for_sale = ?', true)
            .where('spree_variants.id IN (?)', current_vendor.showable_variants.ids)
            .where('account_id = ?', params[:account_id]).update_all(visible: visibility)
        end
        respond_with() do |format|
          format.js {}
          format.html {redirect_to :back}
        end
      end

      def get_lot_info
        @stock_item = Spree::StockItem.find_by_id(params[:stock_item_id])
        @vendor = current_vendor
        respond_to do |format|
          format.js
        end
      end

      def create_lot
        @vendor = current_vendor
        @product = @vendor.products.find(params[:lot][:product])
        if params[:lot] && params[:lot][:available_at].present?
          params[:lot][:available_at] = params[:lot][:available_at] = DateHelper.company_date_to_UTC(params[:lot][:available_at], @vendor.date_format)
        end
        if params[:lot] && params[:lot][:expires_at].present?
          params[:lot][:expires_at] = params[:lot][:expires_at] = DateHelper.company_date_to_UTC(params[:lot][:expires_at], @vendor.date_format)
        end
        if params[:lot] && params[:lot][:sell_by].present?
          params[:lot][:sell_by] = params[:lot][:sell_by] = DateHelper.company_date_to_UTC(params[:lot][:sell_by], @vendor.date_format)
        end
        @lot = @vendor.lots.new(lot_params)

        if @lot.save
          if params[:lot][:stock_location].present? && params[:lot][:variant_id].present?
            stock_item = Spree::StockItem.where(variant_id: params[:lot][:variant_id], stock_location_id: params[:lot][:stock_location]).first
            stock_item_lot = Spree::StockItemLots.new(stock_item: stock_item, lot_id: @lot.id)
            if stock_item_lot.save
              @saved = true
            else
              @lot.errors << "Invalid Stock Location"
              @saved = false
            end
          else
            @saved = false
          end
        else
          @saved = false
        end
        respond_to do |format|
          format.js do
            @lot if @lot
            @saved
          end
        end
      end

      protected

      def product_params
        params.require(:product).permit(:name, :description, :available_on,
        :shipping_category_id, :tax_category_id, :tax_cloud_tic, :product_type,
        :can_be_part, :display_name, :active,
        :for_sale, :for_purchase, :income_account_id, :expense_account_id, :cogs_account_id, :asset_account_id,
          product_option_types_attributes: [:id, :product_id, :option_type_id, :position, :_destroy],
          master_attributes: [:sku, :price, :pack_size, :pack_size_qty, :lead_time, :id, :is_master, :track_inventory, :lot_tracking, :show_parts, :visible_to_all, :display_name,
            :cost_price, :minimum_order_quantity, :incremental_order_quantity, :cost_currency, :weight, :weight_units, :width, :height, :depth, :dimension_units, :tax_category_id,
            :sweetist_lead_time_hours, :sweetist_fragile, :sweetist_dietary_info, :sweetist_max_order_qty, :sweetist_num_servings,
            :costing_method, :avg_cost_price, :last_cost_price, :sum_cost_price,
            :general_account_id, :income_account_id, :cogs_account_id, :asset_account_id, :expense_account_id, :variant_type, :txn_class_id,
            :preferred_vendor_account_id, :text_options,
            parts_variants_attributes: [:id, :assembly_id, :part_id, :count, :_destroy],
            variant_price_lists_attributes: [:id, :price, :_destroy],
            prices_attributes: [:id, :amount],
            vendor_account_ids: [],
            stock_items_attributes: [:id, :backorderable, :min_stock_level]],
          variants_attributes: [:sku, :price, :pack_size, :pack_size_qty, :lead_time, :id, :is_master, :track_inventory, :_destroy, :visible_to_all, :display_name,
            :cost_price, :minimum_order_quantity, :incremental_order_quantity, :cost_currency, :weight, :weight_units, :width, :height, :depth, :dimension_units, :tax_category_id,
            :sweetist_lead_time_hours, :sweetist_fragile, :sweetist_dietary_info, :sweetist_max_order_qty, :sweetist_num_servings,
            :costing_method, :avg_cost_price, :last_cost_price, :sum_cost_price,
            :general_account_id, :income_account_id, :cogs_account_id, :asset_account_id, :expense_account_id, :variant_type, :txn_class_id,
            parts_variants_attributes: [:id, :assembly_id, :part_id, :count, :_destroy],
            option_value_ids: [], prices_attributes: [:id, :amount]],
            option_type_ids: [], taxon_ids: [], sync_to_sales_channel_ids: [])
      end

      def lot_params
        params.require(:lot).permit(
          :number,
          :variant_id,
          :available_at,
          :sell_by,
          :expires_at,
        )
      end

      def load_assemblies_parts
        @vendor = current_vendor
        @product = Spree::Product.friendly.find(params[:id])
        @option_types = @product.option_types.includes(:option_values)
        @assemblies_parts = @product.assemblies_parts.includes(:assembly, :part)
        @lot = @vendor.lots.new
        @sub_product_ids = {}

        if @vendor.lot_tracking
          @stock_lot_variant_count = {}
          @assemblies_parts.each do |part|
            @sub_product_ids[part.part_id] = part.count
            stock_location = {}
            @vendor.stock_locations.each do |location|
              location.stock_item_lots.select{|stock_item_lot| stock_item_lot.variant == part.part}.each do |stock_item_lot|
                stock_location[stock_item_lot.id] = stock_item_lot.count
              end
            end
            @stock_lot_variant_count[part.part.id] = stock_location
          end
          @sub_product_ids = @sub_product_ids.to_json.html_safe
          @stock_lot_variant_count = @stock_lot_variant_count.to_json.html_safe
        else
          @stock_location_variant_count = {}
          @assemblies_parts.each do |part|
            @sub_product_ids[part.part_id] = part.count
            stock_location = {}
            @vendor.stock_locations.each do |location|
              stock_location[location.id] = location.count_on_hand(part.part)
            end
            @stock_location_variant_count[part.part.id] = stock_location
          end
          @sub_product_ids = @sub_product_ids.to_json.html_safe
          @stock_location_variant_count = @stock_location_variant_count.to_json.html_safe
        end
      end

      def backorderable_stock_item_ids
        params[:stock_item] ||= {}
        params[:stock_item].fetch(:backorderable,{}).keys
      end

      def variant_params
        params.require(:variant).permit(option_value_ids: [])
      end

      def ensure_vendor
        @product = Spree::Product.friendly.find(params[:id])
        @vendor ||= current_vendor
        unless @vendor.id == @product.vendor_id
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to root_url
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
          redirect_to :back
        end
      end

      def ensure_subscription_limit
        product_limit = current_company.subscription_limit('products')
        unless current_company.within_subscription_limit?('products', current_company.showable_variants.active.count)
          flash[:error] = "Your subscription is limited to #{product_limit} #{'product'.pluralize(product_limit)}."
          redirect_to manage_products_path
        end
      end
    end
  # /. Vendor
  end
# /. Spree
end
