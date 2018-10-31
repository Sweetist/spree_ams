module Spree
  module Manage
    class CustomerViewableAttributesController < Spree::Manage::BaseController

      before_action :ensure_write_permission

      def show
        redirect_to edit_manage_customer_viewable_attribute_path
      end

      def edit
        @vendor = current_vendor
        @cva = current_vendor.customer_viewable_attribute
        @user_is_viewing_images = @cva.try(:catalog_show_images)
        @current_order = @vendor.sales_orders.new
        @pages_header = @vendor.pages.header_links
        @pages_footer = @vendor.pages.footer_links
        render :edit
      end

      def update
        @vendor = current_vendor
        @cva = current_vendor.customer_viewable_attribute
        @cva.assign_attributes(customer_view_params)
        @current_order = @vendor.sales_orders.new
        @customer_theme_name = @cva.theme_name
        @user_is_viewing_images = @cva.try(:catalog_show_images)

        if @customer_theme_name == "custom"
          add_content_to_cva
        end
        if params[:save]
          unless @theme_css.nil?
            @cva.theme_css = @theme_css
            set_custom_theme_colors if @customer_theme_name == "custom"
          end
          if @cva.save
            flash[:success] = 'Customer view settings updated'
            if params[:customer_viewable_attribute][:theme_name].present?
              redirect_to edit_manage_customer_viewable_attribute_path(anchor: "layout_tab")
            elsif params[:customer_viewable_attribute][:about_us].present?
              redirect_to edit_manage_customer_viewable_attribute_path(anchor: "content_management_tab")
            else
              redirect_to edit_manage_customer_viewable_attribute_path
            end
          else
            flash.now[:errors] = @cva.errors.full_messages
            render :edit
          end
        end
      end

      private

      def customer_view_params
        params.require(:customer_viewable_attribute).permit!
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = 'You do not have permission to view customer view settings'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('company')
          flash[:error] = 'You do not have permission to edit customer view settings'
          redirect_to manage_path
        end
      end

      def add_content_to_cva
        return if params[:customer_viewable_attribute].fetch(:pre_header_background_color, nil).nil?
        @cva.pre_header_background_color = params[:customer_viewable_attribute].fetch(:pre_header_background_color, nil)
        @cva.pre_header_text_color = params[:customer_viewable_attribute].fetch(:pre_header_text_color, nil)
        @cva.header_background_color = params[:customer_viewable_attribute].fetch(:header_background_color, nil)
        @cva.header_text_color = params[:customer_viewable_attribute].fetch(:header_text_color, nil)
        @cva.body_background_color = params[:customer_viewable_attribute].fetch(:body_background_color, nil)
        @cva.body_text_color = params[:customer_viewable_attribute].fetch(:body_text_color, nil)
        @cva.button_background_color = params[:customer_viewable_attribute].fetch(:button_background_color, nil)
        @cva.button_text_color = params[:customer_viewable_attribute].fetch(:button_text_color, nil)
        @cva.footer_background_color = params[:customer_viewable_attribute].fetch(:footer_background_color, nil)
        @cva.footer_text_color = params[:customer_viewable_attribute].fetch(:footer_text_color, nil)
        @cva.announcement_background_color = params[:customer_viewable_attribute].fetch(:announcement_background_color, nil)
        @cva.announcement_text_color = params[:customer_viewable_attribute].fetch(:announcement_text_color, nil)
        @theme_css = @cva.generate_customer_css(
          @cva.pre_header_background_color,
          @cva.pre_header_text_color,
          @cva.header_background_color,
          @cva.header_text_color,
          @cva.body_background_color,
          @cva.body_text_color,
          @cva.button_background_color,
          @cva.button_text_color,
          @cva.footer_background_color,
          @cva.footer_text_color,
          @cva.announcement_background_color,
          @cva.announcement_text_color
        )
      end

      def set_custom_theme_colors
        @cva.theme_colors = {
          'pre_header_background' => @cva.pre_header_background_color,
          'pre_header_text' => @cva.pre_header_text_color,
          'header_background' => @cva.header_background_color,
          'header_text' => @cva.header_text_color,
          'body_background' => @cva.body_background_color,
          'body_text' => @cva.body_text_color,
          'button_background' => @cva.button_background_color,
          'button_text' => @cva.button_text_color,
          'footer_background' => @cva.footer_background_color,
          'footer_text' => @cva.footer_text_color,
          'announcement_background' => @cva.announcement_background_color,
          'announcement_text' => @cva.announcement_text_color
        }
      end

    end
  end
end
