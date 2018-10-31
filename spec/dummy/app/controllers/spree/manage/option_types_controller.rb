module Spree
  module Manage
    class OptionTypesController < Spree::Manage::BaseController
      respond_to :js
      before_action :ensure_read_permission, only: [:index]
      before_action :ensure_write_permission, only: [:edit, :update,]
      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]

      def index
        @vendor = current_vendor
        @option_types = @vendor.option_types.includes(:option_values).order('presentation ASC')
        render :index
      end
      def new
        @vendor = current_vendor
        @option_type = @vendor.option_types.new
        respond_with(@option_type) do |format|
          format.html{ render :new}
          format.js do
            @remote = true
          end
        end
      end

      def create
        @vendor = current_vendor
        set_presentation_values
        @option_type = @vendor.option_types.new(option_type_params)
        if @option_type.save
          respond_with(@option_type) do |format|
            format.html do
              flash[:success] = "Option type added"
              redirect_to manage_option_types_path
            end
            format.js do
              @remote = true
            end
          end
        else
          flash.now[:errors] = @option_type.errors_including_option_values
          respond_with(@option_type) do |format|
            format.html{ render :new }
            format.js do
              @remote = true
            end
          end
        end
      end
      def show
        redirect_to edit_manage_option_type_path(params[:id])
      end

      def edit
        @vendor_id = current_vendor.id

        respond_with(@option_type) do |format|
          format.html{ render :edit }
          format.js do
            @remote = true
          end
        end

      end

      def update
        @vendor = current_vendor
        @option_type = Spree::OptionType.find(params[:id])
        @vendor_id = current_vendor.id

        if params[:variant_id]
          @variant = @vendor.variants_including_master.find_by_id(params[:variant_id])
        end

        set_presentation_values

        if @option_type.update(option_type_params)
          flash[:success] = "Option Type #{@option_type.presentation} updated"

          respond_with(@option_type) do |format|
            format.html{ redirect_to manage_option_types_url }
            format.js do
              @remote = true
            end
          end
        else
          flash.now[:errors] = @option_type.errors_including_option_values
          respond_with(@option_type) do |format|
            format.html{ render :edit }
            format.js do
              @remote = true
            end
          end
        end

      end
      def destroy
        if @option_type.destroy
          flash[:success] = "Option type deleted."
        else
          flash[:errors] = @option_type.errors.full_messages
        end

        redirect_to manage_option_types_path
      end

      private

      def option_type_params
        params.require(:option_type).permit(:name, :presentation, option_values_attributes: [:id, :name, :presentation, :vendor_id, :done, :_destroy])
      end

      def ensure_vendor
        @option_type = Spree::OptionType.find(params[:id])
        @vendor = current_vendor

        unless @option_type.vendor_id == @vendor.id || @option_type.vendor_id.nil?
          flash[:error] = "You do not have permission to view the requested page"
          redirect_to manage_option_types_path
        end
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('option_values', 'products')
          flash[:error] = 'You do not have permission to view product option types'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('option_values', 'products')
          flash[:error] = 'You do not have permission to view product option types'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('option_values', 'products')
          flash[:error] = 'You do not have permission to edit product option types'
          redirect_to manage_option_types_path
        end
      end

      def set_presentation_values
        if params[:option_type][:name].present?
          params[:option_type][:presentation] = params[:option_type][:name]
        end

        if params[:option_type][:option_values_attributes].present?
          params[:option_type][:option_values_attributes].each do |form_id, opt_value|
            opt_value[:presentation] = opt_value[:name]
          end
        end
      end

    end
  end
end
