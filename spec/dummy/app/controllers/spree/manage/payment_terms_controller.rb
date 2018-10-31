module Spree
	module Manage
    class PaymentTermsController < Spree::Manage::BaseController

      before_action :ensure_read_permission

      def index
        @payment_terms = Spree::PaymentTerm.all.order('name ASC')
        render :index
      end

      private

      def ensure_read_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = 'You do not have permission to view company settings'
          redirect_to manage_path
        end
      end

    end
  end
end
