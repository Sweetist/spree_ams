module Spree
  module Manage
    class RefundsController < Spree::Manage::BaseController
      before_action :load_order
      before_action :ensure_write_permission
      helper_method :refund_reasons

      rescue_from Spree::Core::GatewayError, with: :spree_core_gateway_error, only: :create

      def new
        @refund = @payment.refunds.new(amount: @payment.amount)
      end

      def create
        @refund = @payment.refunds.new(refund_params)
        if @refund.save
          flash[:success] = 'Refund created'
          respond_to do |format|
            format.html { redirect_to edit_manage_order_path(@order) }
            format.js { render js: "window.location.reload();" }
          end
        else
          flash.now[:errors] = @refund.errors.full_messages
          render :new
        end
      end

      private

      def refund_params
        params.require(:refund).permit(:amount, :refund_reason_id)
      end

      def location_after_save
        manage_order_payments_path(@payment.order)
      end

      def load_order
        # the spree/admin/shared/order_tabs partial expects the @order instance variable to be set
        @order = current_vendor.sales_orders.friendly.find(params[:order_id])
        @payment = @order.payments.friendly.find(params[:payment_id])
      end

      def refund_reasons
        @refund_reasons ||= RefundReason.active.all
      end

      def build_resource
        super.tap do |refund|
          refund.amount = refund.payment.credit_allowed
        end
      end

      def spree_core_gateway_error(error)
        flash[:error] = error.message
        render :new
      end

      def ensure_write_permission
        if !current_spree_user.can_write?('payments', 'order')
          flash[:error] = 'You do not have permission to edit payments'
          if @order
            redirect_to manage_order_path(@order)
          else
            redirect_to manage_orders_path
          end
        end
      end

    end
  end
end
