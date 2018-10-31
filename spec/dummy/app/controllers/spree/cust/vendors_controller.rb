module Spree
  module Cust
    class VendorsController < Spree::Cust::CustomerHomeController

      before_action :ensure_vendor_account, only: :show

      def index
        # Removing for vendor focused site design
          #####################################
          # clear_current_order
          # @customer = current_customer
          # @my_vendors = @customer.vendors.order('name ASC')
          # @vendors = Vendor.all
          # render :index
          #####################################

          if request.host == ENV['DEFAULT_URL_HOST']
            redirect_to vendor_products_url(current_customer.vendors.first)
          else
            @vendor = current_customer.vendors.where(custom_domain: request.host).first
            if @vendor
              redirect_to vendor_products_url(@vendor)
            else
              redirect_to orders_url
            end
          end
      end

      def show
        redirect_to vendor_products_url(set_current_vendor)
        # redirecting for now until we can make this page look nice and add links in b2b portal
        # @customer = current_customer
        # @vendor = set_current_vendor
        # @account = @vendor.customer_accounts.where('customer_id = ?', current_customer.id).first
        # @recent_orders = @account.orders.order('delivery_date DESC').limit(5)
        # render :show
      end

      private

      def set_current_vendor
        @vendor = Spree::Company.friendly.find(params[:id])
        session[:vendor_id] = @vendor.id
        @vendor
      end

      def ensure_vendor_account
        @customer = current_spree_user.company
        unless @customer.vendors.include?(Spree::Company.friendly.find(params[:id]))
          flash[:error] = "You do not have permission to view the page requested"
          redirect_to root_url
        end
      end

    end
  end
end
