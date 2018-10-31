module Spree
  module Cust
    class CreditCardsController < Spree::Cust::CustomerHomeController
      respond_to :js

      def destroy
        @credit_card = Spree::CreditCard.joins(:account)
                        .where('spree_accounts.id IN (?)', current_spree_user.account_ids)
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
