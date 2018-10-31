module Spree
  module Manage
    class CarriersController < Spree::Manage::BaseController
      before_action :ensure_write_permission
      before_action :load_vendor, only: %i[edit update]

      def show
        redirect_to edit_manage_carriers_path
      end

      def edit
        session[:vendor_id] = @vendor.id
      end

      def update
        update_handling_fee(params[:company])
        update_test_mode_value(params[:company])
        update_valid_credentials
        session[:vendor_id] = @vendor.id
        if @vendor.update(account_params)
          flash[:success] = 'Carriers settings successfully updated'
        else
          flash[:errors] = @vendor.errors.full_messages
        end
        redirect_to edit_manage_carriers_path
      end

      protected

      def load_vendor
        @vendor = current_vendor
      end

      def account_params
        params.require(:company).permit(
          :ups_login, :ups_password, :ups_key,
          :shipper_number, :fedex_login, :units,
          :fedex_password, :fedex_account,
          :fedex_key, :usps_login, :test_mode,
          :usps_commercial_base, :usps_commercial_plus,
          :canada_post_login, :unit_multiplier,
          :handling_fee, :max_weight_per_package,
          :fedex_include_surcharges, :default_weight
        )
      end

      def update_handling_fee(company)
        company[:handling_fee] = company[:handling_fee].to_f * 100
      end

      def update_test_mode_value(company)
        company[:test_mode] = false if company[:test_mode] == '0'
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

      def update_valid_credentials
        @vendor.ups_valid_credentials = ups_carrier(params[:company])
                                        .valid_credentials?
        @vendor.fedex_valid_credentials = fedex_carrier(params[:company])
                                          .valid_credentials?
        @vendor.usps_valid_credentials = usps_carrier(params[:company])
                                         .valid_credentials?
      end

      def fedex_carrier(company)
        carrier_details = {
          key: company['fedex_key'],
          password: company['fedex_password'],
          account: company['fedex_account'],
          login: company['fedex_login'],
          test: company['test_mode']
        }
        ::ActiveShipping::FedEx.new(carrier_details)
      end

      def ups_carrier(company)
        carrier_details = {
          login: company['ups_login'],
          password: company['ups_password'],
          key: company['ups_key'],
          test: company['test_mode']
        }
        ::ActiveShipping::UPS.new(carrier_details)
      end

      def usps_carrier(company)
        carrier_details = {
          login: company['usps_login'],
          test: company['test_mode']
        }

        ::ActiveShipping::USPS.new(carrier_details)
      end
    end
  end
end
