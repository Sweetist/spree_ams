module Spree
  module Manage
    class AdjustmentsController < Spree::Manage::BaseController


      after_action :update_totals, only: [:create, :update, :destroy]
      before_action :ensure_permissions, only: [:new, :create, :edit, :update, :destroy]
      after_action :transition_order, only: [:create, :update]

      def new
        @order = Spree::Order.friendly.find(params[:order_id])
        @adjustment = @order.adjustments.new

        render :new
      end

      def create
        @order = Spree::Order.friendly.find(params[:order_id])
        @adjustment = @order.adjustments.new(order_id: @order.id, label: params[:adjustment][:label], amount: params[:adjustment][:amount].to_f)
        if @adjustment.save(adjustment_params)
          redirect_to edit_manage_order_url(@order)
        else
          flash.now[:errors] = @adjustment.errors.full_messages
          render :new
        end
      end

      def edit
        @adjustment = Spree::Adjustment.find(params[:id])
        render :edit
      end

      def update
        @adjustment = Spree::Adjustment.find(params[:id])
        @order = @adjustment.order

        if @adjustment.update(adjustment_params)
          redirect_to edit_manage_order_url(@order)
        else
          flash.now[:errors] = @adjustment.errors.full_messages
          render :edit
        end
      end

      def destroy
        @adjustment = Spree::Adjustment.find(params[:id])
        @order = @adjustment.order
        @adjustment.destroy!
        redirect_to edit_manage_order_url(@order)
      end

      private

      def adjustment_params
        params.require(:adjustment).permit(:label, :amount)
      end

      def update_totals
        @order.reload.update!
      end

      def ensure_permissions
        current_spree_user.permissions.fetch('order',{}).fetch('manual_adjustment', false)
        unless current_spree_user.permissions.fetch('order',{}).fetch('manual_adjustment', false)
          flash[:error] = 'You do not have permission to make adjustments'
          redirect_to params[:order_id].present? ? edit_manage_order_path(params[:order_id]) : manage_path
        end
      end

      def transition_order
        order = @adjustment.try(:order)
        return unless order
        if order.state == 'approved'
          order.back_to_complete
          order.approve(current_spree_user)
        elsif States[order.state] > States['approved']
          order.trigger_transition
        end
      end

    end
  end
end
