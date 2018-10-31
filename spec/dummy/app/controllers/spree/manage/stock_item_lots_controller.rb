module Spree
  module Manage
    class StockItemLotsController < Spree::Manage::BaseController
      respond_to :js

      CONVERT_TO_UTC_PARAMS = %i[available_at sell_by expires_at].freeze

      def create
        @vendor = current_vendor

        lot = @vendor.lots.new(converted_params[:lot])
        @variant = @vendor.variants_including_master
                         .find(converted_params[:variant_id])
        lot.variant = @variant

        flash.now[:errors] = @stock_item_lot.errors.full_messages unless lot.save

        stock_location = @vendor.stock_locations
                                .find(converted_params[:stock_location_id])
        stock_item = stock_location.stock_items.where(variant: @variant).first_or_create
        stock_item_lot = Spree::StockItemLots.new(lot: lot, stock_item: stock_item)

        if stock_item_lot.save
          flash[:success] = "Lot #{stock_item_lot.lot.number} has been successfully created."
        else
          flash.now[:errors] = stock_item_lot.errors.full_messages
        end

        respond_to do |format|
          format.js
        end
      end

      private

      def converted_params
        converted_params = stock_item_lot_params
        CONVERT_TO_UTC_PARAMS.each do |parameter|
          next if stock_item_lot_params[:lot].blank? || stock_item_lot_params[:lot][parameter].blank?
          converted_params[:lot][parameter] = DateHelper
                                              .company_date_to_UTC(
                                                stock_item_lot_params[:lot][parameter],
                                                current_vendor.date_format)
        end
        converted_params
      end

      def stock_item_lot_params
        params.require(:stock_item_lots).permit(
          { lot: %i[number variant_id available_at sell_by expires_at] },
          :qty_on_hand, :stock_location_id, :variant_id
        )
      end
    end
  end
end
