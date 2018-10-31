module Spree
  module Manage
    class LotsController < Spree::Manage::BaseController
      before_action :ensure_vendor, only: [:edit, :update, :show, :archive, :unarchive]
      before_action :ensure_subscription

      helper_method :display_transfer_type_with_variant

      def index
        @vendor = current_vendor
        @lots = @vendor.lots

        params[:q] ||= {}

        date_fields = %i[
          sell_by_gteq sell_by_lteq available_at_gteq available_at_lteq
          expires_at_gteq expires_at_lteq created_at_gteq created_at_lteq
        ]

        date_fields.each {|date_field| format_ransack_date_field(date_field, @vendor)}

        @in_stock = params[:q][:in_stock].to_bool
        @include_expired = params[:q][:include_expired].to_bool
        @include_archived = params[:q][:include_archived].to_bool

        @lots = @lots.unexpired unless @include_expired
        @lots = @lots.in_stock if @in_stock
        @lots = @lots.unarchived unless @include_archived

        params[:q][:in_stock] = nil
        params[:q][:include_expired] = nil
        params[:q][:include_archived] = nil

        @search = @lots.ransack(params[:q])

        params[:q][:in_stock] = '1' if @in_stock
        params[:q][:include_expired] = '1' if @include_expired
        params[:q][:include_archived] = '1' if @include_archived

        @search.sorts = 'created_at desc' if @search.sorts.empty?
        @lots = @search.result.page(params[:page])

        date_fields.each {|date_field| revert_ransack_date_to_view(date_field, @vendor)}

        render :index
      end

      def new
        @vendor = current_vendor
        @variants = @vendor.showable_variants
                           .active
                           .where(lot_tracking: true)
                           .includes(:product, :option_values)
        @lot = @vendor.lots.new
        render :new
      end

      def create
        @vendor = current_vendor

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
          flash[:success] = "Lot #{@lot.number} has been created."
          redirect_to manage_lots_path
        else
          @variants = @vendor.showable_variants
                             .active
                             .where(lot_tracking: true)
                             .includes(:product, :option_values)
          @stock_location_hash = Hash[@stock_location_list.map{|location_id, qty| [Spree::StockLocation.find_by_id(location_id), qty]}] if @stock_location_list
          @stock_location_list = @stock_location_list.to_json.html_safe
          flash.now[:errors] = @lot.errors.full_messages
          render :new
        end
      end

      def show
        @vendor = current_company
        @lot = @vendor.lots.find(params[:id])
        params[:q] ||= {}
        params[:q][:lots_id_or_lots_part_lots_part_lot_id_eq] = @lot.id
        @orders = Spree::Order.joins(:account).includes(:line_item_lots)
          .where(state: InvoiceableStates)
          .where(
            'spree_accounts.vendor_id = ? or spree_accounts.customer_id = ?',
            @vendor.id, @vendor.id).ransack(params[:q])
                                   .result
                                   .page(params[:orders_page]).per(15)

        @stock_movements = Spree::StockMovement
          .joins('join spree_stock_transfers ON spree_stock_transfers.id = spree_stock_movements.originator_id')
          .where('
            (
              spree_stock_movements.lot_id = ?
            ) OR (
              spree_stock_transfers.transfer_type = ? AND
              spree_stock_transfers.assembly_lot_id = ? AND
              spree_stock_movements.lot_id is not null AND
              spree_stock_movements.lot_id <> ?
            )
            ', @lot.id, 'build', @lot.id, @lot.id
          )
          .page(params[:transfers_page]).per(15)

        unless @lot
          flash[:error] = 'Lot does not exist'
          redirect_to manage_lots_url
        end

        render :show
      end

      def edit
        @vendor = current_vendor
        @lot = @vendor.lots.find(params[:id])
        unless @lot
          flash[:error] = 'Lot does not exist'
          redirect_to manage_lots_url
        end
        @variants = @vendor.variants_including_master
        stock_locations = @lot.stock_item_lots
        render :edit
      end

      def update
        @vendor = current_vendor
        @lot = @vendor.lots.find(params[:id])
        unless @lot
          flash[:error] = 'Lot does not exist'
          redirect_to manage_lots_url
        end
        if params.fetch(:lot, {}).fetch(:stock_location_list, nil).present?
          @stock_location_list = JSON.parse(params[:lot][:stock_location_list])
        else
          @stock_location_list = {}
        end
        if params[:lot] && params[:lot][:available_at].present?
          params[:lot][:available_at] = params[:lot][:available_at] = DateHelper.company_date_to_UTC(params[:lot][:available_at], @vendor.date_format)
        end
        if params[:lot] && params[:lot][:expires_at].present?
          params[:lot][:expires_at] = params[:lot][:expires_at] = DateHelper.company_date_to_UTC(params[:lot][:expires_at], @vendor.date_format)
        end
        if params[:lot] && params[:lot][:sell_by].present?
          params[:lot][:sell_by] = params[:lot][:sell_by] = DateHelper.company_date_to_UTC(params[:lot][:sell_by], @vendor.date_format)
        end

        if @lot.update(lot_params)
          flash[:success] = "Lot #{@lot.number} has been updated."
          redirect_to manage_lots_path
        else
          @stock_location_hash = Hash[@stock_location_list.map{|location_id, qty| [Spree::StockLocation.find_by_id(location_id), qty]}]
          @stock_location_list = @stock_location_list.to_json.html_safe
          @variants = @vendor.variants_including_master.includes(:product, :option_values)

          flash.now[:errors] = @lot.errors.full_messages
          render :edit
        end
      end

      def actions_router
        if params[:all_lots] == 'true'
          lot_ids = []
        elsif params[:company] && params[:company][:lots_attributes]
          params[:company][:lots_attributes] ||= {}
          lot_ids = params[:company][:lots_attributes].map {|k, v| v[:id] if v[:action].to_bool}.compact
        end

        case params[:commit]
        when Spree.t('lots.bulk_actions.archive')
          archive_multiple(params[:all_lots], lot_ids)
        when Spree.t('lots.bulk_actions.unarchive')
          unarchive_multiple(params[:all_lots], lot_ids)
        end

        flash[:success] = 'Lots Updated'
        redirect_to manage_lots_path
      end

      def archive
        @lot.update_columns(archived_at: Time.current) unless @lot.archived?
        flash[:success] = 'Lot archived'
        redirect_to manage_lot_path(@lot)
      end
      def unarchive
        @lot.update_columns(archived_at: nil)
        flash[:success] = 'Lot unarchived'
        redirect_to manage_lot_path(@lot)
      end

      def archive_multiple(all_lots, lot_ids = [])
        if all_lots.to_bool
          current_company.lots.unarchived.update_all(archived_at: Time.current)
        else
          current_company.lots.unarchived.where(
            'spree_lots.id IN (?)', lot_ids
          ).update_all(archived_at: Time.current)
        end
      end

      def unarchive_multiple(all_lots, lot_ids = [])
        if all_lots.to_bool
          current_company.lots.archived.update_all(archived_at: nil)
        else
          current_company.lots.archived.where(
            'spree_lots.id IN (?)', lot_ids
          ).update_all(archived_at: nil)
        end
      end

      private

      def lot_params
        params.require(:lot).permit(
          :number,
          :variant_id,
          :available_at,
          :sell_by,
          :expires_at,
          :qty_on_hand,
          :archive,
          :archived_at
        )
      end

      def ensure_vendor
        @vendor = current_vendor
        @lot = @vendor.lots.find(params[:id])
        unless current_vendor.id == @lot.try(:vendor_id)
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to manage_lots_url
        end
      end

      def ensure_subscription
        unless current_company.subscription_includes?('lot_tracking')
          flash[:error] = 'Lot tracking is not supported by your current subscription'
          redirect_to manage_path
        end
      end
    end
  end
end
