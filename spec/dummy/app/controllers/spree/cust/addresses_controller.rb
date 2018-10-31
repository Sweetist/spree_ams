module Spree
  module Cust
    class AddressesController < Spree::Cust::CustomerHomeController
      respond_to :js, :html
      before_action :set_address, only: [:create, :show, :edit, :update, :destroy]

      def new
        @account = current_customer.vendor_accounts.find_by_id(params[:account_id])
        @address = @account.shipping_addresses.new
      end

      def create
        @account = current_customer.vendor_accounts.find_by_id(params[:account_id])

        @address = if params[:address][:addr_type] == 'shipping'
                     @account.shipping_addresses.new(address_params.except(:order_id))
                   else
                     # billing address
                     @account.billing_addresses.new(address_params.except(:order_id))
                   end

        if @address.save
          @account.update_attributes(bill_address_id: @address.id) if @address.addr_type == 'billing' #save billing address to account
          set_address
          respond_with do |format|
            format.js do
              flash[:success] = 'Address was successfully created.'
            end
          end
        else
          respond_with do |format|
            format.js do
              flash.now[:errors] = @address.errors.full_messages + @account.contact_accounts.map{|a| a.errors.full_messages}
            end
          end
        end
      end

      def edit
        @submit_button_text = params[:order_id] ? "Use Address" : "Save Address"
      end

      def update
        if @address.update(address_params.except(:order_id))
          @account.update_attributes(bill_address_id: @address.id) if @address.addr_type == "billing" #save billing address to account
          set_address
          if address_params[:order_id].presence
            @order_presence = true
            @order = current_customer.purchase_orders.includes(:line_items, :account, customer: :users).friendly.find(address_params[:order_id])
            @order.set_ship_address(@address.id)
            @ship_addresses = @order.account.ship_addresses - [@order.ship_address]
            @ship_addresses.unshift(@order.ship_address)
            set_order_addresses
            if @order.save
              respond_with do |format|
                format.js do
                  flash[:success] = 'Address was successfully updated.'
                end
              end
            else
              respond_with do |format|
                format.js do
                  flash.now[:errors] = @order.errors.full_messages
                end
              end
            end
          else #./ address_params[:order_id] == nil
            respond_with do |format|
              format.js do
                flash[:success] = 'Address was successfully updated.'
              end
            end
          end
          respond_with do |format|
            format.js do
              flash[:success] = 'Address was successfully updated.'
            end
          end
        else
          respond_with do |format|
            format.js do
              flash.now[:errors] = @address.errors.full_messages
            end
          end
        end
      end

      def destroy
        if @address.destroy
          set_address
          respond_with do |format|
            format.js do
              flash[:success] = 'Address was deleted.'
            end
          end
        else
          respond_with do |format|
            format.js do
              flash.now[:errors] = @address.errors.full_messages + @account.contact_accounts.map{|a| a.errors.full_messages}
            end
          end
        end
      end

      private

      def address_params
        params.require(:address).permit(
          :id,
          :firstname,
          :lastname,
          :company,
          :phone,
          :address1,
          :address2,
          :city,
          :country_id,
          :state_name,
          :zipcode,
          :state_id,
          :addr_type,
          :order_id
        )
      end

      def set_address
        country_id = @vendor.try(:bill_address).try(:country_id) || Spree::Address.default.country_id
        @account = current_customer.vendor_accounts.find_by(id: params[:account_id])
        @address = if params[:order_id] || (params[:address] && params[:address][:order_id])
                     Spree::Address.find_by(id: params[:id])
                   elsif params[:addr_type] == 'shipping' || (params[:address] && params[:address][:addr_type] == 'shipping')
                     @account.shipping_addresses.find_by(id: params[:id])
                   else
                     @account.billing_addresses.find_by(id: params[:id])
                   end
        @bill_address = @account.bill_address.present? ? @account.bill_address : @customer.build_bill_address(country_id: country_id)
        @ship_addresses = @account.shipping_addresses - [@account.default_ship_address]

        if @account.default_ship_address
          @selected_ship_address = @account.default_ship_address
        elsif Spree::Address.where(account_id: @account.id, addr_type: 'shipping').first.present?
          @selected_ship_address = Spree::Address.where(account_id: @account.id, addr_type: 'shipping').first
          @account.update_columns(default_ship_address_id: @selected_ship_address.id)
        else
          @selected_ship_address = @customer.build_ship_address(country_id: country_id)
        end
      end

      def set_order_addresses
        if @order.ship_address
          @account_address_ship = @order.ship_address
        elsif @account.default_ship_address
          @account_address_ship = @account.default_ship_address
        else
          @account_address_ship = @account.ship_addresses.new(account_id: @account.id, addr_type: 'shipping')
        end
        if @order.bill_address
          @account_address_bill = @order.bill_address
        elsif @account.bill_address
          @account_address_bill = @account.bill_address
        else
          @account_address_bill = @account.build_bill_address(account_id: @account.id, addr_type: 'billing')
        end
      end
    end
  end
end
