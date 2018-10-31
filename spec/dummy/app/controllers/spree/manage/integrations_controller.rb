module Spree
  module Manage
    class IntegrationsController < Spree::Manage::BaseController
      before_action :ensure_read_permission, only: [:show, :index]
      before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]
      before_action :ensure_admin_user_for_sweetist, only: [:new, :create]
      before_action :ensure_subscription_limit, only: [:new, :create]
      after_action  :update_company_settings, only: [:update]

      def index
        @vendor = current_vendor
        @current_company = current_spree_user.company
        @items = Spree::Integration.available_vendors_integrations(@current_company)
        @integration_limit = @current_company.subscription_limit('integration_limit')
        @integration_count = @current_company.integration_items.where.not(integration_key: 'sweetist').count
      end

      def new
        @item = Spree::Integration.available_vendors_integrations(current_spree_user.company).select {|i| i[:integration_key] == params[:integration]}.first

        if @item.nil? || (@item.fetch(:integrations, []).count > 0 && !@item.fetch(:multi, false))
          redirect_to manage_integrations_path, flash: { error: "You can't register this Integration anymore" }
        else
          @integration = current_spree_user
                         .company
                         .integration_items
                         .new(integration_key: @item.fetch(:integration_key))
          @integration.integration_type = @item.fetch(:integration_type)
          @integration.should_timeout = @item.dig(:should_timeout) || false
          if @item.fetch(:auto_create, false)
            @integration.save
            flash[:success] = 'New integration has been configured!'
            redirect_to edit_manage_integration_path(@integration.id)
          else
            render :new
          end
        end
      end

      def create
        @item = Spree::Integration.available_vendors_integrations(current_spree_user.company).select {|i| i[:integration_key] == params[:integration_item][:integration_key]}.first

        if @item.nil? || (@item.fetch(:integrations, []).count > 0 && !@item.fetch(:multi, false))
          flash.now[:error] = "You can't register this Integration anymore"
          redirect_to manage_integrations_path
        else
          @integration = current_spree_user.company.integration_items.new(integration_params)
          if @integration.save
            try_update_shopify_last_sync_date
            flash[:success] = 'New integration has been configured!'
            redirect_to edit_manage_integration_path(@integration.id)
          else
            flash.now[:error] = @integration.errors.full_messages
            render :new
          end
        end
      end

      def show
        @vendor = current_spree_user.company
        @integration = current_spree_user.company.integration_items.find(params[:id])
        @item = Spree::Integration.available_vendors_integrations(current_spree_user.company).select {|i| i[:integration_key] == @integration.integration_key}.first
        render :show
      end

      def edit
        @vendor = current_spree_user.company
        @integration = current_spree_user.company.integration_items.find(params[:id])
        @item = Spree::Integration.available_vendors_integrations(current_spree_user.company).select {|i| i[:integration_key] == @integration.integration_key}.first
        render :edit
      end

      def update
        @integration = current_spree_user.company.integration_items.find(params[:id])
        @item = Spree::Integration.available_vendors_integrations(current_spree_user.company).select {|i| i[:integration_key] == @integration.integration_key}.first
        try_update_shopify_last_sync_date
        set_last_pulled_at_dates

        if @integration.update(integration_params)

          flash[:success] = 'Integration has been reconfigured!'
          redirect_to manage_integration_path(@integration.id)
        else
          revert_pulled_at_dates_for_view
          flash.now[:errors] = @integration.errors.full_messages
          render :edit
        end
      end

      def destroy
        @integration = current_spree_user.company.integration_items.find(params[:id])
        if @integration.destroy
          flash[:success] = "Integration has been removed!"
          redirect_to manage_integrations_path
        else
          redirect_to manage_integrations_path
          flash[:error] = "Integration could not be removed!"
        end
      end

      def execute
        @integration = current_spree_user.company.integration_items.find(params[:integration_id])
        execution = @integration.execute(params[:name], params, manage_integration_url(@integration.id))
        if execution[:url]
          redirect_to execution[:url], flash: execution[:flash]
        elsif execution[:xml]
          render xml: execution[:xml], content_type: 'text/xml'
        elsif execution[:file_data]
          send_data execution[:file_data], filename: execution[:file_name]
        end
      end

      def enqueue
        integration = current_spree_user.company.integration_items.find(params[:integration_id])
        @integration_action = integration.integration_actions.where(id: params[:id], status: [-1,3]).first
        if @integration_action
          Sidekiq::Client.push('class' => IntegrationWorker, 'queue' => integration.queue_name, 'args' => [@integration_action.id])
          @integration_action.delete_steps
          @integration_action.update_columns(status: 0, enqueued_at: Time.current, execution_log: '', step: nil)
          respond_to do |format|
            format.html do
              redirect_to :back, flash: { success: "Restarted." }
            end
            format.js {}
          end

        else
          respond_to do |format|
            format.html do
              redirect_to :back, flash: { error: "Could not be restarted!" }
            end
            format.js {flash.now[:error] = "Could not be restarted!"}
          end
        end
      end

      def enqueue_variants
        integration = current_spree_user.company.integration_items.find(params[:integration_id])
        all_variants = params[:all_variants].to_s.downcase == 'true'
        integration.sync_many_variants(all_variants)

        if all_variants
          flash[:success] = 'All products will be enqueued shortly'
        else
          flash[:success] = 'Unsynced products will be enqueued shortly'
        end
        redirect_to :back
      end

      def fetch_products
        integration = current_spree_user.company.integration_items.find(params[:integration_id])
        integration.fetch_products

        redirect_to manage_integration_path(integration)
      end

      def fetch_customers
        integration = current_spree_user.company.integration_items.find(params[:integration_id])
        integration.fetch_customers

        redirect_to manage_integration_path(integration)
      end

      def fetch_orders
        integration = current_spree_user.company.integration_items.find(params[:integration_id])
        integration.fetch_orders

        redirect_to manage_integration_path(integration)
      end

      def fetch_credit_memos
        integration = current_spree_user.company.integration_items.find(params[:integration_id])
        integration.fetch_credit_memos

        redirect_to manage_integration_path(integration)
      end

      def fetch_account_payments
        integration = current_spree_user.company.integration_items.find(params[:integration_id])
        integration.fetch_account_payments

        redirect_to manage_integration_path(integration)
      end

      def toggle_skipped_actions
        show_action = session[:show_skipped_action]
        session[:show_skipped_action] = true if show_action.blank?
        session[:show_skipped_action] = false if show_action.present?

        redirect_to :back
      end

      def kill
        integration_item = current_company.integration_items.find(params[:integration_id])

        integration_item.integration_actions.where(status: 1).update_all(status: -10)
        redirect_to :back
      end

      private

      def try_update_shopify_last_sync_date
        last_sync_date = params['integration_item']['shopify_last_sync_order_date']
        return unless last_sync_date
        vendor = @integration.vendor
        save_date = DateHelper.to_db_from_frontend(last_sync_date, vendor)
        @integration.shopify_last_sync_order = save_date
      end

      def set_last_pulled_at_dates
        Spree::Integrations::ItemSharedAttributes::INTEGRATIONS_SHARED_PULL_TYPES.each do |type|
          next unless @integration.send("show_#{type}_last_pulled_at")
          format_form_datetime_field('integration_item', "#{type}_last_pulled_at", @integration.company)
        end
      end

      def revert_pulled_at_dates_for_view
        Spree::Integrations::ItemSharedAttributes::INTEGRATIONS_SHARED_PULL_TYPES.each do |type|
          next unless @integration.send("show_#{type}_last_pulled_at")
          revert_datetime_to_view_format('integration_item', "#{type}_last_pulled_at", @integration.company)
        end
      end

      # Integration Attributes
      def integration_params
        default_params = [
          :integration_key,
          :integration_type,
          # Quickbooks Desktop
          :qbd_password,
          :qbd_match_with_name,
          :qbd_send_order_as,
          :qbd_is_to_be_printed,
          :qbd_invoice_template,
          :qbd_sales_receipt_template,
          :qbd_sales_order_template,
          :qbd_credit_memo_template,
          :qbd_auto_apply_payment,
          :qbd_create_related_objects,
          :qbd_update_related_objects,
          :qbd_overwrite_conflicts_in,
          :qbd_collect_taxes,
          :qbd_group_discounts,
          :qbd_discount_item_name,
          :qbd_discount_account_id,
          :qbd_build_assembly_account_id,
          :qbd_shipping_item_name,
          :qbd_use_assemblies,
          :qbd_use_multi_site_inventory,
          :qbd_use_order_class_on_lines,
          :qbd_sync_class_on_items_and_customers,
          :qbd_track_lots,
          :qbd_track_inventory,
          :qbd_bundle_adjustment_name,
          :qbd_bundle_adjustment_account_id,
          :qbd_deposit_to_account,
          :qbd_accounts_receivable_account,
          :qbd_default_shipping_category_id,
          :qbd_line_item_sort,
          :qbd_force_line_position,
          :qbd_shopify_customer_id,
          :qbd_use_external_balance,
          # Quickbooks Online
          :qbo_key,
          :qbo_secret,
          :qbo_group_sync,
          :qbo_country,
          :qbo_multi_currency,
          :qbo_match_with_name,
          :qbo_send_as_invoice,
          :qbo_send_to_line_description,
          :qbo_custom_field_1,
          :qbo_custom_field_2,
          :qbo_custom_field_3,
          :qbo_include_discounts,
          :qbo_discount_account_id,
          :qbo_include_shipping,
          :qbo_create_related_objects,
          :qbo_include_department,
          :qbo_enforce_channel,
          :qbo_use_categories,
          :qbo_overwrite_conflicts_in,
          :qbo_variant_overwrite_conflicts_in,
          :qbo_customer_overwrite_conflicts_in,
          :qbo_vendor_overwrite_conflicts_in,
          :qbd_overwrite_orders_in,
          :qbo_send_as_non_inventory,
          :qbo_track_inventory,
          :qbo_track_inventory_from,
          :qbo_bill_from_po,
          :qbo_send_as_bundle,
          :qbo_bundle_adjustment_name,
          :qbo_bundle_adjustment_account_id,
          :qbo_deposit_to_account,
          :qbo_include_lots,
          :qbo_include_assembly_lots,
          :qbo_strip_html,
          :qbo_shopify_customer_id,
          :qbd_export_list_to_csv,
          :qbd_initial_order_state,
          :qbd_ungroup_grouped_lines,
          :qbd_send_special_instructions_as,
          :qbd_special_instructions_item,

          # Sweetist Integration
          :sweetist_access_key,
          :sweetist_integration_state,
          :sweetist_send_automated_emails,
          :sweetist_account_name,
          :sweetist_stock_location_id,
          :sweetist_weight_units,
          :sweetist_dimension_units,
          :sweetist_overwrite_conflicts_in,
          :sweetist_min_order_reqmt,
          :sweetist_email,
          :sweetist_phone,
          :sweetist_email,
          :sweetist_address,
          :sweetist_city,
          :sweetist_zipcode,
          :sweetist_address,
          :sweetist_state,
          :sweetist_country,
          :sweetist_open_su,
          :sweetist_open_mo,
          :sweetist_open_tu,
          :sweetist_open_we,
          :sweetist_open_th,
          :sweetist_open_fr,
          :sweetist_open_sa,
          :sweetist_closed_su,
          :sweetist_closed_mo,
          :sweetist_closed_tu,
          :sweetist_closed_we,
          :sweetist_closed_th,
          :sweetist_closed_fr,
          :sweetist_closed_sa,
          # Shipstation Integration
          :shipstation_overwrite_shipping_cost,
          :shipstation_weight_units,
          :shipstation_overwrite_shipping_cost,
          :shipstation_round,
          :shipstation_include_lots,
          :shipstation_include_assembly_lots,
          :shipstation_email_type,
          :shipstation_custom_field_1,
          :shipstation_custom_field_2,
          :shipstation_custom_field_3,

          # Shipping Easy Integration
          :shipping_easy_api_key,
          :shipping_easy_api_secret,
          :shipping_easy_store_api_key,
          :shipping_easy_overwrite_shipping_cost,
          :shipping_easy_round,
          :shipping_easy_include_lots,
          :shipping_easy_include_assembly_lots,

          # Shared Methods
          :limit_shipping_method_by,
          :limit_payment_method_by,
          sales_channel: [],
          shipping_methods: [],
          payment_methods: [],
          qbd_pull_item_types: [],
          qbd_ignore_items: []
        ]

        shopify_params = Spree::ShopifyIntegration::Item.all_settings
        shared_params = Integrations::ItemSharedAttributes.shared_params
        all = default_params + shopify_params + shared_params
        params.require(:integration_item).permit(*all)
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('integrations','settings')
          flash[:error] = 'You do not have permission to view integrations'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('integrations','settings')
          flash[:error] = 'You do not have permission to view integrations'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('integrations','settings')
          flash[:error] = 'You do not have permission to edit integrations'
          redirect_to manage_integrations_path
        end
      end

      def ensure_subscription_limit
        limit = current_company.subscription_limit('integration_limit')
        unless current_company.within_subscription_limit?(
            'integration_limit',
            current_company.integration_items.where.not(integration_key: 'sweetist').count
          )
          flash[:error] = "Your subscription is limited to #{limit} #{'integration'.pluralize(limit)}."
        end
      end

      def ensure_admin_user_for_sweetist
        if (params.fetch(:integration, nil) == 'sweetist' || params.fetch(:integration_item, {}).fetch(:integration_key, nil) == 'sweetist') && !current_spree_user.is_admin?
          flash[:error] = 'Please contact Sweet to set up your Sweetist integration'
          redirect_to :back
        end
      end

      def update_company_settings
        @integration.try(:update_company_settings)
      end
    end

  end
end
