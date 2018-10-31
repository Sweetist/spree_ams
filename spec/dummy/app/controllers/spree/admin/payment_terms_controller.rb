module Spree
  module Admin
    class PaymentTermsController < ResourceController


      def index
        respond_with(@collection) do |format|
          format.html
          format.json { render :json => json_data }
        end

        @payment_terms = Spree::PaymentTerm.all

      end


      def new
        @payment_term = Spree::PaymentTerm.new
        render :new
      end

      def create
        @payment_term = Spree::PaymentTerm.new(payment_term_params)
        if @payment_term.save
          flash[:success] = flash_message_for(@payment_term, :successfully_created)
          redirect_to admin_payment_terms_path
        else
          render :new
          flash.now[:errors] =  @payment_term.errors.full_messages
        end
      end

      def update
        @payment_term = Spree::PaymentTerm.find(params[:id])
        if @payment_term.update(payment_term_params)
          flash[:success] = 'Payment Term Updated'
          redirect_to admin_payment_terms_path
        else
          flash.now[:errors] =  @payment_term.errors.full_messages
          render :edit
        end
      end

      private

      def payment_term_params
			  params.require(:payment_term).permit(
          :name,
          :description,
          :num_days,
          :pay_before_submit     
        )
      end
		end
	end
end
