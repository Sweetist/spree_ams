module Spree
  module Manage
    class TaxonsController < Spree::Manage::BaseController
      respond_to :js

      before_action :ensure_read_permissions, only: [:index]
      before_action :ensure_write_permissions, only: [:new, :create, :edit, :update, :destroy]

      def index
        @vendor = current_vendor
        @user_can_edit_taxons = current_spree_user.can_write?('categories', 'products')
        @taxonomies = @vendor.taxonomies.includes(:taxons)
      end

      def new
        @vendor = current_vendor
        @taxon = @vendor.taxons.new(parent_id: params[:parent_id], taxonomy_id: @vendor.taxonomies.first.try(:id))
        params[:parent_id] = nil
      end

      def create
        @vendor = current_vendor
        @taxon = @vendor.taxons.new(taxon_params)
        vendor_taxonomy = @vendor.taxonomies.first || @vendor.taxonomies.create(name: @vendor.name)
        @taxon.taxonomy_id = vendor_taxonomy.try(:id)
        @taxon.parent_id ||= vendor_taxonomy.try(:root).try(:id)

        if @taxon.save
          flash[:success] = 'Category Saved'
          redirect_to manage_taxons_path
        else
          flash.now[:errors] = @taxon.errors.full_messages
          render :new
        end
      end

      def edit
        @vendor = current_vendor
        @taxon = @vendor.taxons.find(params[:id])
        @parent = @taxon.parent
      end

      def update
        @vendor = current_vendor
        @taxon = @vendor.taxons.find(params[:id])

        if @taxon.update(taxon_params)
          flash[:success] = 'Category Updated'
          redirect_to manage_taxons_path
        else
          flash.now[:errors] = @taxon.errors.full_messages
          render :edit
        end
      end

      def destroy
        @vendor = current_vendor
        @taxon = @vendor.taxons.find_by_id(params[:id])
        if @taxon.try(:destroy)
          respond_with do |format|
            format.html do
              flash.now[:success] = "Category #{@taxon.name} deleted"
              redirect_to manage_taxons_path
            end
            format.js {@taxon}
          end
          flash[:success] = 'Category Deleted'
        else
          respond_with do |format|
            format.html do redirect_to manage_promotions_url
              flash.now[:error] = "Could not delete category #{@taxon.try(:name)}"
              redirect_to manage_taxons_path
            end
            format.js {@taxon = nil}
          end
        end
      end

      private

      def taxon_params
        params.require(:taxon).permit(:name, :parent_id, :top_level)
      end

      def ensure_read_permissions
        if current_spree_user.cannot_read?('categories', 'products')
          flash[:error] = 'You do not have permission to view product categories'
          redirect_to manage_path
        end
      end

      def ensure_write_permissions
        if current_spree_user.cannot_read?('categories', 'products')
          flash[:error] = 'You do not have permission to view product categories'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('categories', 'products')
          flash[:error] = 'You do not have permission to edit product categories'
          redirect_to manage_taxons_path
        end
      end

    end
  end
end
