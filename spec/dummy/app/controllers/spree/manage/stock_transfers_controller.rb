module Spree
  module Manage
    class StockTransfersController < Spree::Manage::BaseController
      before_action :ensure_subscription
      before_action :ensure_read_permission, only: [:show, :index]
      before_action :ensure_edit_permission, only: [:new, :create]
      before_action :ensure_tracking_inventory, only: [:new, :create, :build_inventory]
      before_action :ensure_variants_info_exist, only: %i[create]
      before_action :ensure_lots_info_exist,
                    only: %i[create],
                    if: :variants_with_lots_tracking?
      before_action :ensure_destination_location_exist, only: %i[build_inventory]

      respond_to :js

      def index
        @vendor = current_vendor
        @stock_transfers = @vendor.stock_transfers
      end

      def new
        @vendor = current_vendor
        @stock_transfer = @vendor.stock_transfers.new
        @lot = @vendor.lots.new
        @variants = @vendor.showable_variants
                           .active
                           .includes(:product, :option_values)
                           .where(lot_tracking: true)
        render :new
      end

      def create_lot
        @vendor = current_vendor
        @variant = Spree::Variant.find_by_id(params[:lot][:variant_id])
        if @variant.present?
          @source_stock = @variant.stock_items.where(stock_location_id: params[:lot][:source_id]).first
          @destination_stock = @variant.stock_items.where(stock_location_id: params[:lot][:destination_id]).first
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
        @lot = @vendor.lots.new(lot_params)

        if @lot.save
          @saved = true
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

      def create
        @vendor = current_vendor
        @stock_transfer = @vendor.stock_transfers.new(stock_transfer_params)

        errors = nil

        if @stock_transfer.save
          begin
            if variants_with_lots_tracking?
              @stock_transfer.transfer_with_lots(@stock_transfer.source_location,
                                                 @stock_transfer.destination_location,
                                                 variants_info,
                                                 params[:lots])
            else
              @stock_transfer.transfer(@stock_transfer.source_location,
                                       @stock_transfer.destination_location,
                                       variants_info)
            end
          rescue StandardError => e
            errors = e
          end

          unless errors
            @stock_transfer.notify_integration
            flash[:success] = Spree.t(:stock_successfully_transferred)
            redirect_to manage_stock_transfers_path and return
          end
        end

        @lot = @vendor.lots.new
        @variants = @vendor.showable_variants
                           .active
                           .includes(:product, :option_values)
                           .where(lot_tracking: true)

        if errors.present?
          flash.now[:errors] = [errors.to_s]
        else
          flash.now[:errors] = @stock_transfer.errors.full_messages
        end

        @stock_transfer.destroy! if @stock_transfer.persisted?
        render :new
      end

      def show
        @vendor = current_vendor
        @stock_transfer = @vendor.stock_transfers.friendly.find(params[:id])
        @all_movements = @stock_transfer.stock_movements
        @split_movements = {}
        @stock_transfer.stock_movements.includes(stock_item: :stock_location).each do |sm|
          @split_movements[sm.stock_item.try(:stock_location).try(:name) || '(Deleted)'] ||= []
          @split_movements[sm.stock_item.try(:stock_location).try(:name) || '(Deleted)'] << sm
        end
      end

      def update
        @vendor = current_vendor
        @stock_transfer = @vendor.stock_transfers.friendly.find(params[:id])
        @all_movements = @stock_transfer.stock_movements
        @split_movements = {}
        @stock_transfer.stock_movements.includes(stock_item: :stock_location).each do |sm|
          @split_movements[sm.stock_item.try(:stock_location).try(:name) || '(Deleted)'] ||= []
          @split_movements[sm.stock_item.try(:stock_location).try(:name) || '(Deleted)'] << sm
        end

        if @stock_transfer.update(stock_transfer_update_params)
          respond_to do |format|
            format.html do
              flash[:success] = "#{@stock_transfer.display_transfer_type} updated."
              redirect_to manage_stock_transfers_path
            end
            format.js {}
          end

        else
          respond_to do |format|
            flash.now[:errors] = @stock_transfer.errors.full_messages
            format.html do
              flash[:success] = "#{@stock_transfer.display_transfer_type} updated."
              render :show
            end
            format.js {}
          end
        end
      end

      def current_stock
        @vendor = current_vendor
        @variant = Spree::Variant.find(params[:variant_id])
        @source_stock = @variant.stock_items.where(stock_location_id: params[:source_id]).first
        @destination_stock = @variant.stock_items.where(stock_location_id: params[:destination_id]).first
        @lots_qty_on_hand = {}

        respond_with(@variant, @source_stock, @destination_stock) do |format|
          format.js {}
        end
      end

      def build_inventory
        @build_inventory = true
        @vendor = current_vendor
        @product = Spree::Product.find_by_id(params[:build_assembly][:product_id])
        errors = nil
        @stock_transfer = @vendor.stock_transfers.create!(
          transfer_type: 'build',
          destination_location_id:destination_location_id_on_build,
          note: params[:build_assembly][:note]
        )
        begin
          if @vendor.lot_tracking && params[:build_assembly][:assembly_stock_item_lot]
            @stock_transfer.build_assembly_with_lots(
              params[:build_assembly][:product_qty].to_f,
              params[:build_assembly][:variant_location],
              params[:build_assembly][:variant_count],
              params[:build_assembly][:assembly_stock_item_lot],
              params[:build_assembly][:assembly_id]
            )
          else
            @stock_transfer.build_assembly(
              params[:build_assembly][:product_qty].to_f,
              params[:build_assembly][:variant_location],
              params[:build_assembly][:variant_count],
              params[:build_assembly][:assembly_stock_location],
              params[:build_assembly][:assembly_id]
            )
          end
        rescue Exception => e
          errors = e
        end

        unless errors
          @stock_transfer.notify_integration
          flash[:success] = Spree.t(:stock_successfully_transferred)
          # redirect_to "#{edit_manage_product_path(@product)}#tab_stock"
          redirect_to :back and return
        end

        flash[:errors] = @stock_transfer.errors.full_messages + [errors.to_s]
        @stock_transfer.destroy! if @stock_transfer.persisted?
        if errors
          redirect_to :back
        end
      end

      private

      def destination_location_id_on_build
        non_lot_id = params.dig(:build_assembly, :assembly_stock_location)
        return non_lot_id if non_lot_id

        assembly_stock_item_lot = params[:build_assembly][:assembly_stock_item_lot]
        return unless assembly_stock_item_lot
        return if assembly_stock_item_lot == 'New Lot'

        Spree::StockItemLots.find(assembly_stock_item_lot).stock_location.id
      end

      def ensure_destination_location_exist
        return if destination_location_id_on_build

        flash[:error] = 'Destination location can not be null'
        redirect_to :back
      end

      def ensure_variants_info_exist
        return if variants_info.present?

        flash[:errors] = ['There is nothing to transfer.']
        redirect_to new_manage_stock_transfer_path
      end

      def variants_info
        return unless params.dig(:stock_transfer, :variants)

        variants = Hash.new(0)
        params.dig(:stock_transfer, :variants).each do |variant_id, quantity|
          variants[variant_id] += quantity.to_f
        end
        variants
      end

      def stock_transfer_params
        params.require(:stock_transfer).permit(:reference, :source_location_id, :destination_location_id, :is_transfer, :general_account_id, :note)
      end

      def build_assembly_params
        params.require(:build_assembly).permit(:product_qty, :assembly_stock_location, :note, :variant_count, :assembly_id, {:variant_location => [:variant_id, :location_id]})
      end

      def stock_transfer_update_params
        params.require(:stock_transfer).permit(:note, :reference)
      end

      def ensure_subscription
        unless current_company.subscription_includes?('inventory')
          flash[:error] = Spree.t(:invalid_subscription_access)
          redirect_to manage_inventory_path
        end
      end

      def lot_params
        params.require(:lot).permit(
          :number,
          :variant_id,
          :available_at,
          :sell_by,
          :expires_at
        )
      end

      def variants_with_lots_tracking?
        return false unless current_company.lot_tracking
        Spree::Variant.where(id: variants_info.keys, lot_tracking: true).present?
      end

      def ensure_lots_info_exist
        return true if params[:lots]

        flash[:errors] = ['Please create a lot to add/take stock of a lot tracked item']
        redirect_to new_manage_stock_transfer_path
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('basic_options', 'inventory')
          flash[:error] = 'You do not have permission to view stock transfers'
          redirect_to manage_path
        end
      end

      def ensure_edit_permission
        if current_spree_user.cannot_read?('basic_options', 'inventory')
          flash[:error] = "You do not have permission to view stock transfers"
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('basic_options', 'inventory')
          flash[:error] = "You do not have permission to edit stock transfers"
          redirect_to manage_stock_transfers_path
        end
      end

      def ensure_tracking_inventory
        redirect_to manage_inventory_path unless current_vendor.track_inventory
      end
    end
  end
end
