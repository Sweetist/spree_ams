module Spree
  module Manage
    class CreditCardsController < Spree::Manage::BaseController
      respond_to :js

      def destroy
        @credit_card = Spree::CreditCard.joins(account: :vendor)
                        .where('spree_companies.id = ?', current_company.id)
                        .where('spree_credit_cards.id = ?', params[:id])
                        .first

        if @credit_card
          @credit_card.update_columns(deleted_at: Time.current) unless @credit_card.deleted_at
          respond_to do |format|
            format.html do
              flash[:success] = 'Credit card deleted.'
              redirect_to :back
            end
            format.js do
              flash.now[:success] = 'Credit card deleted.'
              render :destroy
            end
          end
        else
          respond_to do |format|
            format.html do
              flash[:error] = 'Could not find credit card.'
              redirect_to :back
            end
            format.js do
              flash.now[:error] = 'Could not find credit card.'
              render :destroy
            end
          end
        end
      end

    end
  end
end
