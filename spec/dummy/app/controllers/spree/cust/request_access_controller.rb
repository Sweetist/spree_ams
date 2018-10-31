module Spree
  module Cust
    class RequestAccessController < Spree::BaseController

      layout 'session'

      def request_access
        @vendor = Spree::Company.where(custom_domain: request.host).first
        @vendor ||= Spree::Company.friendly.find(params[:vendor_id]) rescue nil
        if @vendor.nil? && session[:spree_user_return_to].to_s.include?('shop')
          vendor_id = session[:spree_user_return_to].split('/')[2]
          @vendor ||= Spree::Company.friendly.find(vendor_id) rescue nil
        end

        if @vendor.present?
          render :request_access
        else
          flash[:error] = 'Could not find vendor'
          redirect_to root_path
        end
      end

      def submit_request
        @vendor = Spree::Company.where(custom_domain: request.host).first
        @vendor ||= Spree::Company.friendly.find(params[:vendor_id]) rescue nil
        if @vendor.nil? && session[:spree_user_return_to].to_s.include?('shop')
          vendor_id = session[:spree_user_return_to].split('/')[2]
          @vendor ||= Spree::Company.friendly.find(vendor_id) rescue nil
        end
        if @vendor
          VendorMailer.request_access(@vendor, params[:spree_user]).deliver_now

          if @vendor.request_account_form.try(:success_message).present?
            flash[:info] = @vendor.request_account_form.success_message
          else
            flash[:success] = "Request submitted to #{@vendor.name}!"
          end
          redirect_to root_url
        else
          flash[:error] = 'We could not find the company you were looking for.'
          redirect_to root_url
        end
      end

      def user_details
        @vendor = Spree::Company.where(custom_domain: request.host).first
        @vendor ||= Spree::Company.friendly.find(params[:vendor_id]) rescue nil
        if @vendor.nil? && session[:spree_user_return_to].to_s.include?('shop')
          vendor_id = session[:spree_user_return_to].split('/')[2]
          @vendor ||= Spree::Company.friendly.find(vendor_id) rescue nil
        end
        @user = Spree::User.where(email: params[:user_email]).first
        @existing_user = false
        if @user && (!@user.company.vendor_accounts.where(vendor_id: @vendor.try(:id)).blank? || @user.company_id == @vendor.try(:id))
          @existing_user = true
        end
        respond_to do |format|
          format.js {
            @user
            @existing_user
          }
        end
      end

    end
  end
end
