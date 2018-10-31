module Spree
  module Manage
    class FormsController < Spree::Manage::BaseController

      respond_to :js
      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :ensure_write_permission, only: [:new, :edit, :create, :update, :destroy]

      def index
        @forms = current_company.forms
      end

      def new
        @form = current_company.forms.new
      end

      def create
        @form = current_company.forms.new(form_params)

        if @form.save
          flash[:success] = 'New form created.'
          redirect_to manage_forms_path
        else
          flash.now[:errors] = @form.errors.full_messages
          render :new
        end
      end

      def show

      end

      def preview
        @form = current_company.forms.new(preview_params)
        render :show
      end

      def edit

      end

      def update
        if @form.update(form_params)
          flash[:success] = 'Form updated.'
          redirect_to manage_forms_path
        else
          flash.now[:errors] = @form.errors.full_messages
          render :edit
        end
      end

      def destroy
        if @form.destroy
          flash[:success] = 'Form deleted.'
        else
          flash[:errors] = 'Could not delete form.'
        end
        redirect_to manage_forms_path
      end

      private

      def form_params
        params.require(:form).permit(
          :name, :title, :form_type, :active, :instructions, :submit_text,
          :num_columns, :success_message, :link_to_text,
          fields_attributes: [
            :id, :label, :field_type, :position,
            :required, :num_columns, :css_class, :_destroy
          ]
        )
      end

      def preview_params
        params.require(:form).permit(
          :name, :title, :form_type, :active, :instructions, :submit_text, :num_columns,
          fields_attributes: [
            :label, :field_type, :position,
            :required, :num_columns, :css_class
          ]
        )
      end

      def ensure_vendor
        @form = Spree::Form.find_by_id(params[:id])
        unless current_vendor.id == @form.vendor_id
          flash[:error] = "You don't have permission to view the requested page"
          redirect_to manage_forms_path
        end
      end

      def ensure_write_permission
        if !current_spree_user.can_write?('company')
          flash[:error] = 'You do not have permission to edit forms'
          redirect_to manage_forms_path
        end
      end
    end
  end
end
