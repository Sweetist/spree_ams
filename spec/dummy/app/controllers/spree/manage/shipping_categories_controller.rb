module Spree
  module Manage
    class ShippingCategoriesController < Spree::Manage::BaseController

      respond_to :js
      before_action :ensure_read_permissions, only: [:index]
      before_action :ensure_write_permissions, only: [:new, :create, :show, :edit, :update, :destroy]

      def index
        @vendor = current_vendor
        @shipping_categories = @vendor.shipping_categories
        @shipping_attached = []
        @shipping_categories.each do |shipping_catg|
          if shipping_catg.shipping_methods.count > 0 || shipping_catg.products.count > 0
            @shipping_attached << shipping_catg.id
          end
        end
        render :index
      end

      def new
        @vendor = current_vendor
        @shipping_category = @vendor.shipping_categories.new
        render :new
      end

      def create
        @vendor = current_vendor
        @shipping_category = @vendor.shipping_categories.new(shipping_category_params)
        if @shipping_category.save(shipping_category_params)
          flash[:success] = "New shipping category saved"
          redirect_to manage_shipping_categories_url
        else
          flash[:errors] = @shipping_category.errors.full_messages
          render :new
        end
      end

      def show
        @vendor = current_vendor
        respond_with do |format|
          format.html do
            redirect_to edit_manage_shipping_category_path(params[:id])
          end
          # response to ajax call from delete button
          format.js do
              @target_shipping_categories = @vendor.shipping_categories.find(params[:id])
              @other_shipping_categories = @vendor.shipping_categories.where.not(id: params[:id])
              unless @target_shipping_categories.shipping_methods.count > 0 || @target_shipping_categories.products.count > 0
                @dettached_shipping_category = true
              end
            render layout: false
          end
        end
      end

      def edit
        @vendor = current_vendor
        @shipping_category = @vendor.shipping_categories.find_by_id(params[:id])
        @reattach_category_delete = false
        @vendor.shipping_methods.each do |shipping_meth|
          shipping_meth.shipping_method_categories.where(shipping_category_id: @shipping_category.id).each do |shipping_catg|
            if @shipping_category.shipping_methods.any? || @shipping_category.products.any?
              @reattach_category_delete = true
            end
          end
        end
        render :edit
      end

      def update
        @vendor = current_vendor
        @shipping_category = @vendor.shipping_categories.find(params[:id])

        if @shipping_category.update(shipping_category_params)
          flash[:success] = "Shipping category updated"
          redirect_to manage_shipping_categories_url
        else
          flash[:errors] = @shipping_category.errors.full_messages
          render :edit
        end
      end

      def destroy
        @vendor = current_vendor
        @shipping_category = @vendor.shipping_categories.find(params[:id])
        if @vendor.shipping_categories.count > 1
          # reassign shipping category before deleting
          @shipping_category.prep_for_deletion(params[:id], params[:new_shipping_category_id], @vendor.id)
          if @shipping_category.destroy!
            respond_with do |format|
              format.html do
                flash[:success] = "Shipping category #{@shipping_category.try(:name)} deleted"
                redirect_to manage_shipping_categories_url
              end
              format.js {@shipping_category}
            end
          else
            respond_with do |format|
              format.html do
                flash[:error] = "Could not delete shipping category #{@shipping_category.try(:name)}"
                redirect_to manage_promotion_categories_url
              end
              format.js {@shipping_category = nil}
            end
          end
        end

      end

      private

      def shipping_category_params
        params.require('shipping_category').permit(:name)
      end

      def ensure_read_permissions
        if current_spree_user.cannot_read?('shipping_categories', 'settings')
          flash[:error] = 'You do not have permission to view shipping categories'
          redirect_to manage_path
        end
      end

      def ensure_write_permissions
        if current_spree_user.cannot_read?('shipping_categories', 'settings')
          flash[:error] = 'You do not have permission to view shipping categories'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('shipping_categories', 'settings')
          flash[:error] = 'You do not have permission to edit shipping categories'
          redirect_to manage_shipping_categories_path
        end
      end

    end
  end
end
