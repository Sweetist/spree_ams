module Spree
  module Cust
    class ReceivingsController < Spree::Cust::CustomerHomeController
      helper_method :sort_column, :sort_direction
      before_action :clear_current_order
      before_action :ensure_customer, only: [:edit, :update]




      def update
        @order = Spree::Order.friendly.find(params[:id])
        # @shipment = Spree::Shipment.friendly.find(params[:id])
        # @order = @shipment.order
        @shipment = @order.shipments.first

        @shipment.receiver_id = current_spree_user.id
        @shipment.received_at = Time.current

        if params[:commit] == 'Reject Order'
          @shipment.line_items.each do |line_item|
            line_item.quantity = 0
            line_item.confirm_received = false
          end
          @shipment.receive
          @order.next
          @order.save!
          redirect_to orders_url
        elsif params[:order][:line_items_attributes].none? {|li, attrs| attrs[:confirm_received] == '1'} #checks that at least one item has been received
          flash[:error] = "You must mark the items that you received or reject the entire order"
          redirect_to edit_order_url(@order)
          # render :edit
        elsif @order.update(receiving_params)
          item_count = 0
          @order.line_items.each do |line_item|
            line_item.quantity = 0 unless line_item.quantity && line_item.confirm_received
            # line_item.received_total = line_item.received_amount
            item_count += line_item.quantity
          end
          @order.item_count = item_count
          @order.update!
          @order.save

          @order.next
          @shipment.receive
          # @order.update!
          Spree::OrderUpdater.new(@order).update
          @order.save!
          redirect_to orders_url
        else
          flash[:errors] = @order.errors.full_messages
          redirect_to edit_order_url(@order)
        end
      end

      private

      def receiving_params
        params.require(:order).permit(
            line_items_attributes: [:id, :confirm_received, :quantity]
          )
      end

      def ensure_customer
	      # @shipment = Spree::Shipment.friendly.find(params[:id])
        # unless current_customer.id == @shipment.order.customer_id
        @order = Spree::Order.friendly.find(params[:id])
        unless spree_current_user.vendor_accounts.find_by_id(@order.try(:account_id)).present?
  				flash[:error] = "You don't have permission to view the requested page"
  	      redirect_to root_url
        end
      end

    end
  end
end
