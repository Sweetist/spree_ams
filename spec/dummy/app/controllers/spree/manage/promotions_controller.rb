module Spree
  module Manage
    class PromotionsController < Spree::Manage::BaseController

      respond_to :js
      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :ensure_read_permissions, only: [:show, :index]
      before_action :ensure_write_permissions, only: [:new, :create, :edit, :update, :destroy]

      def index
        @vendor = current_vendor
        @customers = @vendor.customers
        @promotions = filter_promotions
        @search = @promotions.ransack(params[:q])
        @promotions = @search.result.page(params[:page])
        render :index
      end

      def new
        @vendor = current_vendor
        @promotion = @vendor.promotions.new(advertise: true)
        @promotion_categories = @vendor.promotion_categories
        @promotion_rules = []
        @promotion_actions = []
        render :new
      end

      def create
        @vendor = current_vendor
        format_form_date_field(:promotion, :starts_at, @vendor)
        format_form_date_field(:promotion, :expires_at, @vendor)

        @promotion = current_vendor.promotions.new(promotion_params)
        @promotion_categories = @vendor.promotion_categories

        @promotion_rules = @promotion.update_promo_rules(params[:promotion][:rules]) if params.fetch(:promotion, {}).fetch(:rules, nil)
        @promotion_actions = @promotion.update_promo_action(params[:promotion][:actions]) if params.fetch(:promotion, {}).fetch(:actions, nil)

        if @promotion.save
          flash[:success] = "Pricing adjustment has been saved."
          redirect_to manage_promotion_path(@promotion)
        else
          @promotion_rules ||= []
          @promotion_actions ||= []
          flash.now[:errors] = @promotion.errors.full_messages
          render :new
        end
      end

      def show
        @vendor = current_vendor
        @promotion = Spree::Promotion.find(params[:id])
        @promotion_categories = @vendor.promotion_categories
        render :show
      end

      def edit
        @vendor = current_vendor
        @promotion = Spree::Promotion.find(params[:id])
        @promotion_rules = @promotion.rules
        @promotion_actions = @promotion.actions
        @promotion_categories = @vendor.promotion_categories
        render :edit
      end

      def update
        @vendor = current_vendor

        format_form_date_field(:promotion, :starts_at, @vendor)
        format_form_date_field(:promotion, :expires_at, @vendor)

        @promotion = Spree::Promotion.find(params[:id])
        @promotion_categories = @vendor.promotion_categories

        @promotion_rules = @promotion.update_promo_rules(params[:promotion][:rules]) if params.fetch(:promotion, {}).fetch(:rules, nil)
        @promotion_actions = @promotion.update_promo_action(params[:promotion][:actions]) if params.fetch(:promotion, {}).fetch(:actions, nil)

        if @promotion.update(promotion_params)
          flash[:success] = "Pricing adjustment has been updated."
          redirect_to manage_promotion_path(@promotion)
        else
          @promotion_rules ||= []
          @promotion_actions ||= []
          flash.now[:errors] = @promotion.errors.full_messages
          render :edit
        end
      end

      def destroy
        @promotion = Spree::Promotion.find(params[:id])
        if @promotion.destroy!
          respond_with do |format|
            format.html do
              flash[:success] = "Pricing adjustment #{@promotion.name} deleted"
              redirect_to manage_promotions_url
            end
            format.js do
              flash.now[:success] = "Pricing adjustment #{@promotion.name} deleted"
              @promotion
            end
          end
        else
          respond_with do |format|

            format.html do
              flash[:error] = "Could not delete pricing adjustment #{@promotion.try(:name)}"
              redirect_to manage_promotions_url
            end
            format.js do
              flash.now[:error] = "Could not delete pricing adjustment #{@promotion.try(:name)}"
              @promotion = nil
            end
          end
        end

      end

      private

      def ensure_vendor
        @promotion = Spree::Promotion.find_by_id(params[:id])
        unless @promotion && current_vendor.id == @promotion.vendor_id
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to root_url
        end
      end

      def promotion_params
        params.require(:promotion).permit(:name, :code, :path, :advertise, :match_policy,
          :description, :promotion_category_id, :usage_limit, :starts_at, :expires_at
          # promotion_rules_attributes:
          )
      end

      def filter_promotions
        @promotions = @vendor.promotions
          .includes(:vendor, :promotion_category, :promotion_actions, :promotion_rules)
        unless params[:account_id].blank?
          @promotions = @promotions
          .where(id: @vendor.customer_accounts.find_by_id(params[:account_id]).try(:promotion_ids))
        end
        unless params[:product_id].blank?
          @promotions = @promotions
          .where(id: @vendor.products.find_by_id(params[:product_id]).try(:promotion_ids))
        end
        @promotions
      end

      def ensure_read_permissions
        if current_spree_user.cannot_read?('promotions')
          flash[:error] = 'You do not have permission to view pricing adjustments'
          redirect_to manage_path
        end
      end

      def ensure_write_permissions
        if current_spree_user.cannot_read?('promotions')
          flash[:error] = 'You do not have permission to view pricing adjustments'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('promotions')
          flash[:error] = "You do not have permission to edit pricing adjustments"
          redirect_to manage_promotions_path
        end
      end

    end
  end
end
