module Spree
  module Manage
    class CitiesController < Spree::Manage::BaseController
      respond_to :js
      def new
        @city = Spree::City.new
        respond_to do |format|
          format.html { render :new }
          format.js {}
        end
      end

      def create
        @city = Spree::City.new(city_params)
        if @city.save
          flash[:success] = "#{@city.state_and_city} added"
          respond_to do |format|
            format.html { redirect_to :back }
            format.js {}
          end
        else
          flash.now[:errors] = @city.errors.full_messages
          respond_to do |format|
            format.html { render :new }
            format.js { render :new }
          end
        end
      end

      private

      def city_params
        params.require(:city).permit(:name, :state_id)
      end
    end
  end
end
