module Spree
  module Manage
    class BookkeepingDocumentsController < ResourceController
      before_action :load_order, if: :order_focused?
      before_action :load_invoice, if: :invoice_focused?

      helper_method :order_focused?, :invoice_focused?

      def show
        respond_with(@bookkeeping_document) do |format|
          format.pdf do
            send_data @bookkeeping_document.pdf, type: 'application/pdf', disposition: 'inline'
          end
        end
      end

      def index
        # Massaging the params for the index view like Spree::Admin::Orders#index
        params[:q] ||= {}
        @search = Spree::BookkeepingDocument.ransack(params[:q])
        @bookkeeping_documents = @search.result
        @bookkeeping_documents = @bookkeeping_documents.where(printable: @order) if order_focused?
        @bookkeeping_documents = @bookkeeping_documents.page(params[:page] || 1).per(10)
      end

      private

      def order_focused?
        params[:order_id].present?
      end

      def invoice_focused?
        params[:invoice_id].present?
      end

      def load_order
        @order = Spree::Order.find_by(number: params[:order_id])
      end
      def load_invoice
        @invoice = Spree::Invoice.find_by(number: params[:invoice_id])
      end
    end
  end
end
