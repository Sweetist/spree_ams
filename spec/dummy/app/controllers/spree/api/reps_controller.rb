module Spree
  module Api
    class RepsController < Spree::Api::BaseController

      def index
        @reps = Spree::Rep.all
        respond_with(@reps)
      end

      def show
        @rep = Spree::Rep.find(params[:id])
        respond_with(@rep)
      end

      private

      def rep
        @rep ||= Spree.rep_class.accessible_by(current_ability, :read).find(params[:id])
      end

      def rep_params
        params.require(:rep).permit(permitted_rep_attributes)
      end

    end
  end
end
