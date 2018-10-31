module Spree
  module Manage
    class PagesController < Spree::Manage::ResourceController
      before_action :ensure_read_permission, only: [:index]
      before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]
      before_action :load_vendor

      def index
        @pages = @vendor.pages
        if @vendor.custom_domain.present?
          render :index
        else
          render :set_custom_domain
        end
      end

      def new
        @page = @vendor.pages.new
        @page.stores << current_store
        if @vendor.custom_domain.present?
          render :new
        else
          render :set_custom_domain
        end
      end

      def create
        @page = @vendor.pages.new(page_params)
        if @page.save
          flash[:success] = "Page #{@page.title} successfully created."
          redirect_to manage_pages_path
        else
          flash[:errors] = @page.errors.full_messages
          render :new
        end
      end

      def edit
        @page = @vendor.pages.find(params[:id])
      end

      def update
        @page = @vendor.pages.find(params[:id])
        if @page.update(page_params)
          flash[:success] = "Page #{@page.title} successfully updated."
          redirect_to edit_manage_page_path(@page)
        else
          flash[:errors] = @page.errors.full_messages
          render :edit
        end
      end

      def destroy
        @page = @vendor.pages.find(params[:id])
        if @page.destroy
          flash[:success] = 'Page removed.'
        else
          flash[:error] = "Could not remove page #{@page.title}"
        end

        respond_to do |format|
          format.js {}
          format.html { redirect_to manage_pages_path }
        end
      end

      private

      def page_params
        params.require(:page).permit(
          :title, :slug, :body, :layout, :foreign_link,
          :position, :show_in_sidebar, :show_in_header,
          :show_in_footer, :visible, :render_layout_as_partial,
          :meta_title, :meta_keywords, :meta_description, store_ids: []
        )
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = "You do not have permission to view order rules"
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = "You do not have permission to view order rules"
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('company')
          flash[:error] = "You do not have permission to edit order rules"
          redirect_to manage_path
        end
      end

      def load_vendor
        @vendor = current_company
      end
    end
  end
end
