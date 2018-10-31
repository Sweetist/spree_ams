module Spree
  module Api
    class PaymentTermsController < Spree::Api::BaseController

      def index
        @payment_terms = Spree::PaymentTerm.all
        respond_with(@payment_terms)
      end

      def show
        @payment_term = Spree::PaymentTerm.find(params[:id])
        respond_with(@payment_term)
      end

      private

      def payment_term
        @payment_term ||= Spree.payment_term_class.accessible_by(current_ability, :read).find(params[:id])
      end

      def payment_term_params
        params.require(:payment_term).permit(permitted_payment_term_attributes)
      end

    end
  end
end
