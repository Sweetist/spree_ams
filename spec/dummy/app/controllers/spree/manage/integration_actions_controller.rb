module Spree
  module Manage
    class IntegrationActionsController < Spree::Manage::BaseController
      before_action :ensure_write_permission, only: [:destroy, :destroy_successful, :destroy_all]
      def destroy
        @action = current_vendor.integration_item_actions.find_by_id(params[:id])
        unless @action.try(:destroy)
          flash[:error] = 'Could not remove sync'
        end
        respond_to do |format|
          format.html {redirect_to :back}
          format.js {}
        end
      end

      def destroy_successful
        integration_item = current_vendor.integration_items.find_by_id(params[:integration_id])
        integration_item.integration_actions.where('status >= ?', 5).delete_all rescue nil
        redirect_to :back
      end

      def destroy_all
        # only destroy completed actions
        #status 0 => enqueued, 1 => processing
        integration_item = current_vendor.integration_items.find_by_id(params[:integration_id])
        integration_item.integration_actions.where.not(status: [0,1]).delete_all rescue nil
        redirect_to :back
      end

      private

      def ensure_write_permission

        unless current_spree_user.can_write?('integrations', 'settings')
          flash[:error] = 'You do not have permission to perform that action'
          redirect_to :back
        end
      end
    end
  end
end
