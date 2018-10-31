module Spree
  module Manage
    class TaxCategoriesController < Spree::Manage::BaseController

      respond_to :js
      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :ensure_read_permission, only: [:index, :show]
      before_action :ensure_write_permission, only: [:new, :edit, :create, :update, :destroy]

      def index
        @tax_categories = current_vendor.tax_categories
        respond_with do |format|
          format.html
          format.json { render :json => @tax_categories }
        end
      end

      def new
        @vendor = current_vendor
        @tax_category = @vendor.tax_categories.new
        render :new
      end

      def create
        @vendor = current_vendor
        @tax_category = @vendor.tax_categories.new(tax_category_params)
        if @tax_category.save
          flash[:success] = "New tax category saved"
          redirect_to manage_tax_categories_path
        else
          flash.now[:errors] = @tax_category.errors.full_messages
          render :new
        end
      end

      def edit
        @vendor = current_vendor
        @tax_category = @vendor.tax_categories.find(params[:id])
        @category_in_use = @tax_category.is_in_use?
      end

      def update
        @vendor = current_vendor
        @tax_category = @vendor.tax_categories.find(params[:id])
        if @tax_category.update(tax_category_params)
          flash[:success] = "#{@tax_category.name} updated"
          redirect_to manage_tax_categories_path
        else
          flash.now[:errors] = @tax_category.errors.full_messages
          render :edit
        end
      end

      def destroy
        @vendor = current_vendor
        @tax_category = Spree::TaxCategory.find(params[:id])
        if @vendor.tax_categories.count > 1
          # if param of new tax category id is passed in we need to use it
          #   to replace the tax category being deleted
          unless params[:new_id].nil?
            @tax_category.prep_for_deletion(params[:new_id])
          end

          if @tax_category.destroy!
            respond_with do |format|
              format.html do
                flash[:success] = "Tax category #{@tax_category.try(:name)} deleted"
                redirect_to manage_tax_categories_url
              end
              format.js do
                flash.now[:success] = "Tax category #{@tax_category.try(:name)} deleted"
                @tax_category
              end
            end
          else
            respond_with do |format|
              format.html do
                flash[:error] = "Could not delete tax category #{@tax_category.try(:name)}"
                redirect_to manage_tax_categories_url
              end
              format.js do
                flash.now[:error] = "Could not delete tax category #{@tax_category.try(:name)}"
                @tax_category = nil
              end
            end
          end
        else
          respond_with do |format|
            format.html do
              flash[:error] = "You must have at least one tax category"
              redirect_to manage_tax_categories_url
            end
            format.js do
              flash.now[:error] = "You must have at least one tax category"
              @tax_category = nil
            end
          end
        end

      end

      private
        def tax_category_params
          params.require(:tax_category).permit(
            :name,
            :tax_code,
            :description,
            :is_default,
          )
        end

        def ensure_vendor
          @tax_category = Spree::TaxCategory.find(params[:id])
          unless current_vendor.id == @tax_category.vendor_id
            flash[:error] = "You don't have permission to view the requested page"
            redirect_to root_url
          end
        end


        def ensure_read_permission
          if current_spree_user.cannot_read?('tax_categories', 'settings')
            flash[:error] = 'You do not have permission to view tax categories'
            redirect_to manage_path
          end
        end

        def ensure_write_permission
          if current_spree_user.cannot_read?('tax_categories', 'settings')
            flash[:error] = 'You do not have permission to view tax categories'
            redirect_to manage_path
          elsif current_spree_user.cannot_write?('tax_categories', 'settings')
            flash[:error] = 'You do not have permission to edit tax categories'
            redirect_to manage_tax_categories_path
          end
        end
    end
  end
end
