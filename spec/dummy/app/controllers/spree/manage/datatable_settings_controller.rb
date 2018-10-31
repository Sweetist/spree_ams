module Spree
  module Manage
    class DatatableSettingsController < Spree::BaseController
      before_action :authenticate_spree_user!
      before_action :datatable_setting_params

      def load_state
        datatable_setting = current_spree_user.datatable_settings.find_or_create_by!(path_name: params[:path_name])
        respond_to do |format|
          format.json { render json: datatable_setting.state }
        end
      end

      def save_state
        datatable_setting = current_spree_user.datatable_settings.find_or_create_by!(path_name: params[:path_name])
        if datatable_setting.update(state: params[:state], user: current_spree_user)
          msg = { message: 'Success!' }
        else
          msg = { message: 'Failed to save_state' }
        end
        respond_to do |format|
          format.json { render json: msg }
        end
      end

      private

      def datatable_setting_params
        params.permit(:state, :path_name)
      end
    end
  end
end
