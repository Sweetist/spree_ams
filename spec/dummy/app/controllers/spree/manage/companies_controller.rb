module Spree
  module Manage
    class CompaniesController < Spree::Manage::BaseController
      respond_to :js
      before_action :ensure_read_permission, only: [:show]
      before_action :ensure_write_permission, only: [:edit, :update, :colors]
      def show
        @account = spree_current_user.company

        country_id = Address.default.country.id
        @account.build_bill_address(country_id: country_id) if @account.bill_address.nil?
        @account.bill_address.country_id = country_id if @account.bill_address.country.nil?
        @bill_address = @account.bill_address

        session[:company_id] = @account.id
        render :show
      end

      def edit
        @account = spree_current_user.company

        country_id = Address.default.country.id
        @account.build_bill_address(country_id: country_id) if @account.bill_address.nil?
        @account.bill_address.country_id = country_id if @account.bill_address.country.nil?
        @bill_address = @account.bill_address

        session[:company_id] = @account.id
        render :edit
      end

      def update
        @account = spree_current_user.company
        session[:company_id] = @account.id
        if @account.update(account_params)
          flash[:success] = "Account has been updated!"
          respond_with(@account) do |format|
            format.html do
              flash[:success] = "Account has been updated!"
              redirect_to edit_manage_account_url
            end
            format.js do
              flash.now[:success] = "Account has been updated!"
            end
          end
        else
          respond_with(@account) do |format|
            flash.now[:errors] = @account.errors.full_messages
            format.html do
              render :edit
            end
            format.js {}
          end

        end
      end

      def update_states
        @available_states = Spree::State.where("country_id = ?", params[:country_id]).order('name ASC')
          respond_to do |format|
          format.js {@available_states}
        end
      end

      def colors
        if request.post?
          @account = spree_current_user.company
          @account.theme_name = params[:company].fetch(:theme_name)
          @theme_name = @account.theme_name
          if @theme_name == "custom"
            @account.header_background_color = params[:company].fetch(:header_background_color)
            @account.header_text_color = params[:company].fetch(:header_text_color)
            @account.sidebar_background_color = params[:company].fetch(:sidebar_background_color)
            @account.sidebar_text_color = params[:company].fetch(:sidebar_text_color)
            @theme_css = @account.generate_css(
              @account.header_background_color,
              @account.header_text_color,
              @account.sidebar_background_color,
              @account.sidebar_text_color
            )
          end
          if params[:save]
            @account.theme_css = @theme_css
            if @theme_name == "custom"
              @account.theme_colors = {
                'header_background' => @account.header_background_color,
                'header_text' => @account.header_text_color,
                'sidebar_background' => @account.sidebar_background_color,
                'sidebar_text' => @account.sidebar_text_color
              }
            end
            if @account.save
              flash[:notice] = "Your Vendor colors have been updated!"
            else
              flash[:error] = "Unable to update your Vendor colors."
            end
          end
          render :edit
        end
      end

      def delete_data
        @account = spree_current_user.company

        begin
          unless params[:confirm_with_email] == current_spree_user.email
            raise Exceptions::DataIntegrity.new("Invalid email for confirmation. Please confirm action by typing your email.")
          end

          Sidekiq::Client.push(
            'class' => DeleteDataWorker,
            'queue' => 'data_integrity',
            'args' => [@account.id, delete_data_params]
          )
          flash.now[:success] = 'Data is being deleted. You will receive confirmation when complete.'
        rescue Exceptions::DataIntegrity => e
          flash[:success] = nil
          flash.now[:error] = e.message
        end

        respond_to do |format|
          format.js {render :update}
          format.html { redirect_to :back }
        end
      end

      def reset_inventory
        @account = spree_current_user.company
        begin
          unless params[:confirm_with_email] == current_spree_user.email
            raise Exceptions::DataIntegrity.new("Invalid email for confirmation. Please confirm action by typing your email.")
          end
          @account.reset_inventory!
          flash.now[:success] = 'Inventory has been reset.'
        rescue Exceptions::DataIntegrity => e
          flash[:success] = nil
          flash.now[:error] = e.message
        end

        respond_to do |format|
          format.js {render :update}
          format.html { redirect_to :back }
        end
      end

      private

      def delete_data_params
        params.require(:company).permit(
          Spree::Company::Resets::RESET_EVENT_ORDER.map{ |event| "destroy_#{event}".to_sym }
        )
      end

      def account_params
        company_params = params.require(:company).permit(
          :name,
          :email,
          :time_zone,
          :order_cutoff_time,
					:show_suggested_price,
          :line_item_tax_categories,
          :currency,
          :date_format,
          :theme_name,
          :header_background_color,
          :header_text_color,
          :sidebar_background_color,
          :sidebar_text_color,
          :week_starts_on,
          :track_inventory,
          :lot_tracking,
          :auto_assign_lots,
          :show_account_balance,
          :notify_daily_summary,
          :notify_order_review,
          :notify_daily_shipping_reminder,
          :notify_discontinued_product,
          :notify_order_confirmation,
          :notify_low_stock,
          ship_address_attributes: [ :id, :firstname, :lastname, :company, :phone, :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id  ],
          bill_address_attributes: [ :id, :firstname, :lastname, :company, :phone, :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id  ]
        )

      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = 'You do not have permission to view company settings'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = 'You do not have permission to view company settings'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('company')
          flash[:error] = 'You do not have permission to edit company settings'
          redirect_to manage_path
        end
      end

    end
  end
end
