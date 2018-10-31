module Spree
  module Manage
    class PromotionCategoriesController < Spree::Manage::BaseController

      respond_to :js
      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :ensure_read_permission, only: [:index]
      before_action :ensure_write_permission, only: [:new, :show, :edit, :create, :update, :destroy]

      def index
        @promotion_categories = current_vendor.promotion_categories
        render :index
      end

      def new
        @promotion_category = current_vendor.promotion_categories.new
        render :new
      end

      def create
        @promotion_category = current_vendor.promotion_categories.new(promotion_category_params)
        if @promotion_category.save
          flash[:sucess] = "Pricing adjustment category saved"
          redirect_to manage_promotion_categories_path
        else
          flash.now[:error] = @promotion_category.errors.full_messages
          render :new
        end
      end

      def show
        redirect_to edit_manage_promotion_category_path(params[:id])
      end

      def edit
        @promotion_category = Spree::PromotionCategory.find(params[:id])
        render :edit
      end

      def update
        @promotion_category = Spree::PromotionCategory.find(params[:id])
        if @promotion_category.update(promotion_category_params)
          flash[:success] = "Pricing adjustment category updated"
          redirect_to manage_promotion_categories_path
        else
          flash.now[:error] = @promotion_category.errors.full_messages
          render :edit
        end
      end

      def destroy
        @promotion_category = Spree::PromotionCategory.find(params[:id])
        if @promotion_category.destroy!
          respond_with do |format|
            format.html do
              flash[:success] = 'Pricing adjustment category deleted'
              redirect_to manage_promotion_categories_path
            end
            format.js {@promotion_category}
          end
        else
          respond_with do |format|
            format.html do
              flash[:error] = 'Could not delete pricing adjustment category'
              redirect_to manage_promotion_categories_path
            end
            format.js {@promotion_category = nil}
          end
        end

      end

      private

      def promotion_category_params
        params.require(:promotion_category).permit(:code, :name)
      end

      def ensure_vendor
        @category = Spree::PromotionCategory.find_by_id(params[:id])
        unless @category && @category.vendor_id == current_vendor.id
          flash[:error] = 'You do not have permission to view the requested page.'
          redirect_to root_path
        end
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('promotions')
          flash[:error] = 'You do not have permission to view pricing adjustment categories'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('promotions')
          flash[:error] = 'You do not have permission to view pricing adjustment categories'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('promotions')
          flash[:error] = 'You do not have permission to edit pricing adjustment categories'
          redirect_to manage_promotion_categories_path
        end
      end

    end
  end
end
