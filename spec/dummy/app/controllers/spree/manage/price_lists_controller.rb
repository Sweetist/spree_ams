module Spree
  module Manage
    class PriceListsController < Spree::Manage::BaseController

      respond_to :js
      before_action :ensure_using_price_lists
      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :ensure_read_permissions, only: [:show, :index]
      before_action :ensure_write_permissions, only: [:new, :create, :edit, :update, :destroy]

      def index
        @search = current_company.price_lists.ransack(params[:q])
        @price_lists = @search.result.page(params[:page])

      end

      def new
        @price_list = current_company.price_lists.new
      end

      def create
        @price_list = current_company.price_lists.new(price_list_params)

        if @price_list.save
          @price_list.update_avvs
          flash[:success] = 'Price list created.'
          respond_to do |format|
            format.html { redirect_to manage_price_lists_path }
            format.js { render js: "window.location.href = '" + manage_price_lists_path + "'" }
          end
        else
          flash.now[:errors] = @price_list.errors.full_messages
          respond_to do |format|
            format.html { render :new }
            format.js { render :form_response }
          end
        end
      end

      def show
        redirect_to edit_manage_price_list_path(params[:id])
      end

      def edit
        render :edit
      end

      def update
        variant_ids = []
        params[:price_list][:price_list_variants_attributes] ||= {}
        params[:price_list][:price_list_variants_attributes].map do |k, v|
          variant_ids << v[:variant_id] if v[:variant_id].present?
        end
        account_ids = []
        params[:price_list][:price_list_accounts_attributes] ||= {}
        params[:price_list][:price_list_accounts_attributes].map do |k, v|
          account_ids << v[:account_id] if v[:account_id].present?
        end

        if @price_list.update(price_list_params)
          @price_list.remove_old_accounts(account_ids)
          @price_list.remove_old_variants(variant_ids)
          @price_list.update_avvs

          flash[:success] = 'Price list updated.'
          respond_to do |format|
            format.html { redirect_to manage_price_lists_path }
            format.js { render js: "window.location.href = '" + manage_price_lists_path + "'" }
          end
        else
          flash.now[:errors] = @price_list.errors.full_messages
          respond_to do |format|
            format.html { render :edit }
            format.js { render :form_response }
          end
        end
      end

      def destroy
        respond_to do |format|
          format.js do
            if @price_list.destroy
              flash.now[:success] = "Price list deleted."
            else
              flash.now[:error] = 'Could not delete price list.'
            end
          end
          format.html do
            if @price_list.destroy
              flash[:success] = "Price list deleted."
            else
              flash[:error] = 'Could not delete price list.'
            end
            redirect_to manage_price_lists_path
          end
        end
      end

      def add_account
        @idx = params[:idx].to_i
        @account = current_company.customer_accounts.find(params[:account_id]) rescue nil
        respond_to do |format|
          format.js {render :add_account}
        end
      end

      def accounts_by_type
        @price_list = current_company.price_lists.find_by_id(params[:price_list_id])
        @customer_type_id = params[:customer_type_id]
        @accounts = []
        @price_list_accounts = []

        if @price_list
          load_price_list_accounts(@price_list, @customer_type_id)
        else
          build_price_list_accounts(@customer_type_id)
        end

      end

      def add_variant
        @idx = params[:idx].to_i
        @variant = current_company.variants_for_sale.find(params[:variant_id]) rescue nil
        respond_to do |format|
          format.js {render :add_variant}
        end
      end

      def variants_by_category
        @price_list = current_company.price_lists.find_by_id(params[:price_list_id])
        @category_id = params[:category_id]
        @variants = []
        @price_list_variants = []

        if @price_list
          load_price_list_variants(@price_list, @category_id)
        else
          build_price_list_variants(@category_id)
        end

      end

      def clone
        original = current_company.price_lists.find_by_id(params[:id])
        if original.nil?
          flash[:error] = 'Could not find price list to clone'
          redirect_to :back and return;
        end
        @price_list = original.dup
        n = 1
        @price_list.name = "#{original.name}(#{n})"
        while current_company.price_lists.where(name: @price_list.name).exists? do
          n += 1
          @price_list.name = "#{original.name}(#{n})"
        end

        @price_list.price_list_accounts_attributes = original.price_list_accounts.map do |pla|
          {id: '', account_id: pla.account_id}
        end
        @price_list.price_list_variants_attributes = original.price_list_variants.map do |plv|
          {id: '', variant_id: plv.variant_id, price: plv.price}
        end

        render :new
      end

      private

      def load_price_list_accounts(price_list, customer_type_id)
        if customer_type_id.present?
          case customer_type_id
          when 'all'
            @price_list_accounts = price_list.price_list_accounts.includes(account: :customer)
            @accounts = current_company.customer_accounts
              .includes(:customer)
              .active
              .where.not(id: @price_list_accounts.pluck(:account_id))
              .order(:fully_qualified_name)
          when 'individual'
            @price_list_accounts = price_list.price_list_accounts.includes(account: :customer)
            @accounts = []
          else
            @customer_type = current_company.customer_types.find(customer_type_id) rescue nil

            @price_list_accounts = price_list.price_list_accounts
                                                  .joins(account: :customer)
                                                  .where('spree_accounts.customer_type_id = ?', @customer_type_id)
                                                  .order('spree_accounts.fully_qualified_name asc')

            @accounts = current_company.customer_accounts
                                       .includes(:customer)
                                       .active
                                       .where(customer_type_id: @customer_type_id)
                                       .where.not(id: @price_list_accounts.map(&:account_id))
                                       .order(:fully_qualified_name)
          end
        end
      end

      def build_price_list_accounts(customer_type_id)
        if customer_type_id.present?
          case customer_type_id
          when 'all'
            @accounts = current_company.customer_accounts
              .includes(:customer)
              .active
              .order(:fully_qualified_name)
          when 'individual'
            @accounts = []
          else
            @customer_type = current_company.customer_types.find(customer_type_id) rescue nil

            @accounts = current_company.customer_accounts
                                       .includes(:customer)
                                       .active
                                       .where(customer_type_id: @customer_type_id)
                                       .order(:fully_qualified_name)
          end
        end
      end

      def load_price_list_variants(price_list, category_id)
        if category_id.present?
          case category_id
          when 'all'
            @price_list_variants = price_list.price_list_variants
                                             .includes(variant: [:product, :default_price])
                                             .order('spree_variants.fully_qualified_name asc')
            @variants = current_company.variants_for_sale
                                       .includes(:default_price)
                                       .where.not(id: @price_list_variants.map(&:variant_id))
                                       .order(:fully_qualified_name)
          when 'individual'
            @price_list_variants = price_list.price_list_variants
                                             .includes(variant: [:product, :default_price])
                                             .order('spree_variants.fully_qualified_name asc')
            @variants = []
          else
            @category = current_company.taxons.find(@category_id)
            @category_name = current_company.taxons.find(@category_id).pretty_name rescue nil

            variants_ids_in_category = current_company.variants_for_sale.where(
                'spree_products.id in (?) OR spree_variants.id in (?)',
                @category.product_ids, @category.variant_ids
              )
              .order(:fully_qualified_name).ids

            @price_list_variants = price_list.price_list_variants
                                             .includes(variant: [:product, :default_price])
                                             .where(variant_id: variants_ids_in_category)
                                             .order('spree_variants.fully_qualified_name asc')

            @variants = current_company.variants_for_sale.where(
                'spree_products.id in (?) OR spree_variants.id in (?)',
                @category.product_ids, @category.variant_ids
              )
              .includes(:default_price)
              .where.not(id: @price_list_variants.map(&:variant_id))
              .order(:fully_qualified_name).distinct
          end
        end
      end

      def build_price_list_variants(category_id)
        if category_id.present?
          case category_id
          when 'all'
            @variants = current_company.variants_for_sale
                                       .includes(:default_price)
                                       .order(:fully_qualified_name)
          when 'individual'
            @variants = []
          else
            @category = current_company.taxons.find(@category_id)
            @category_name = current_company.taxons.find(@category_id).pretty_name rescue nil
            @variants = current_company.variants_for_sale
              .includes(:default_price)
              .where(
                'spree_products.id in (?) OR spree_variants.id in (?)',
                @category.product_ids, @category.variant_ids
              ).order(:fully_qualified_name).distinct
          end
        end
      end

      def price_list_params
        params.require(:price_list).permit(
          :name,
          :select_customers_by,
          :select_variants_by,
          :customer_type_id,
          :adjustment_method,
          :adjustment_operator,
          :adjustment_value,
          :active,
          price_list_accounts_attributes: [
            :id,
            :account_id,
            :_destroy
          ],
          price_list_variants_attributes: [
            :id,
            :variant_id,
            :price,
            :_destroy
          ]
        )
      end

      def ensure_using_price_lists
        unless current_company.try(:use_price_lists)
          flash[:error] = 'Price lists have not yet been enabled for your company. Please contact help@getsweet.com.'
          redirect_to manage_path
        end
      end

      def ensure_vendor
        @price_list = Spree::PriceList.find_by_id(params[:id])
        unless @price_list && current_company.id == @price_list.vendor_id
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to manage_price_lists_path
        end
      end

      def ensure_read_permissions
        if current_spree_user.cannot_read?('promotions')
          flash[:error] = 'You do not have permission to view price lists'
          redirect_to manage_path
        end
      end

      def ensure_write_permissions
        if current_spree_user.cannot_read?('promotions')
          flash[:error] = 'You do not have permission to view price lists'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('promotions')
          flash[:error] = "You do not have permission to edit price lists"
          redirect_to manage_promotions_path
        end
      end

    end
  end
end
