module Spree
  module Manage
    class ShipmentsController < Spree::Manage::BaseController
      before_action :ensure_order_not_shipped, only: :update_all
      before_action :ensure_write_permission
      def index
        @company = current_company
        @order = Spree::Order.find_by_number(params[:order_id])
        @order = @company.sales_orders.friendly.find(params[:order_id]) rescue nil
        @order ||= @company.purchase_orders.friendly.find(params[:purchase_order_id])
        @vendor = @order.vendor
        @shipments = @order.shipments.includes(:stock_location)

        if @vendor.id == @company.id
          render :index
        else
          render :po_index
        end
      end

      def update_all
        @vendor = @order.vendor
        prev_shipment = @order.shipments.first
        begin
          variants_hash = Hash.new(0)
          @order.line_items.each_with_index do |item, idx|
            variants_hash["#{item.variant_id}_#{idx}"] += item.quantity
          end
          stock_location_id = stock_location_params.fetch(:shipments_attributes,{}).fetch('0',{}).fetch(:stock_location_id, nil)
          if prev_shipment.transfer_many_to_location(variants_hash, stock_location_id)
            @order.reload.line_items.each(&:auto_assign_lots)
            if States[@order.state] >= States['complete']
              @order.line_items.includes(:inventory_units).each do |line_item|
                line_item.update_inventory unless line_item.quantity == line_item.inventory_units.count
              end
            end
            flash.now[:success] = "Stock has been reallocated"
          else
            flash[:error] = "Insufficient stock at the selected location"
          end
        rescue Exception => e
          flash[:error] = e.message
        end
        redirect_to edit_manage_order_path(@order)
      end

      private

      def stock_location_params
        params.require(:order).permit(shipments_attributes: [:stock_location_id, :id])
      end

      def ensure_order_not_shipped
        @order = current_company.sales_orders.friendly.find(params[:order_id])
        if States[@order.state] >= States['shipped']
          flash[:error] = "This order has already shipped. You cannot change the stock location"
          redirect_to edit_manage_order_path(@order)
        elsif States[@order.state] < States['cart']
          flash[:error] = 'This order can no longer be edited.'
          redirect_to edit_manage_order_path(@order)
        end
      end

      def ensure_write_permission
        user = current_spree_user
        unless user.can_write?('basic_options', 'order') && user.permission_order_approve_ship_receive
          flash[:error] = 'You do not have permission to edit shipments'
          redirect_to :back
        end
      end

    end
  end
end
