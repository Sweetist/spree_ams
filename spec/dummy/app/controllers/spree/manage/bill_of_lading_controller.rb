module Spree
  module Manage
    class BillOfLadingController < Spree::Manage::BaseController

      helper_method :sort_column, :sort_direction

      before_action :ensure_vendor, only: [:show, :edit, :update]

      def show
        @order = Spree::Order.friendly.find(params[:id])
        @bookkeeping_document = @order.pdf_bill_of_lading_for_order
        respond_with(@bookkeeping_document) do |format|
          format.pdf do
            send_data @bookkeeping_document.pdf, type: 'application/pdf', disposition: 'inline'
          end
        end
      end

      private

      def ensure_vendor
        @order = Spree::Order.friendly.find(params[:id])
        unless current_vendor.id == @order.vendor_id
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to root_url
        end
      end
    end
  end
end
