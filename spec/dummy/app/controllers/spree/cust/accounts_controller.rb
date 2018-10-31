module Spree
  module Cust
    class AccountsController < Spree::Cust::CustomerHomeController
      before_action :clear_current_vendor_account, only: :index
      before_action :load_account, only: [:show, :edit, :update]
      respond_to :js

      def index
        if request.host == ENV['DEFAULT_URL_HOST']
          @accounts = spree_current_user.vendor_accounts.includes(:vendor).order('fully_qualified_name ASC')
        else
          @accounts = spree_current_user.vendor_accounts.where(vendor_id: current_vendor.try(:id)).includes(:vendor).order('fully_qualified_name ASC')
        end
        render :index
      end

      def edit
        set_address
        render :edit
      end

      def show
        redirect_to edit_account_path(params[:id])
      end

      def update
        session[:vendor_account_id] = @account.id
        if @account.update(account_params)
          flash[:success] = 'Account has been updated!'
          redirect_to edit_account_path(@account)
        else
          flash[:errors] = @account.errors.full_messages
          render :edit
        end
      end

      def user_accounts
        @account = current_customer.vendor_accounts.find(params[:account_id])
        if (params[:accounts][:user_id] != "")
          @user = current_customer.users.find(params[:accounts][:user_id])
          @user_account = @user.user_accounts.new(account_id: @account.id)
          if @user_account.save
            flash[:success] = "User added to account #{@account.fully_qualified_name}"
            redirect_to edit_account_path(@account)
          else
            flash[:errors] = @user_account.errors.full_messages
            redirect_to new_account_user_path(@account)
          end
        else
          flash[:error] = "Please select a user"
          redirect_to new_account_user_path(@account)
        end

      end

      def update_default_address
        @account = current_customer.vendor_accounts.find(params[:id])
        @customer = @account.customer
        @address = @account.ship_addresses.find_by_id(params[:address_id])

        @account.set_default_ship_address(@address.id) if @address

        if @account.save
          set_address
          respond_to do |format|
            format.js do
              flash[:success] = 'Default address successfully saved.'
            end
          end
        else
          respond_to do |format|
            format.js do
              flash.now[:errors] = @account.errors.full_messages
            end
          end
        end
      end

      def update_states
        @available_states = Spree::State.where("country_id = ?", params[:country_id]).order('name ASC')
          respond_to do |format|
          format.js {@available_states}
        end
      end

      private

      def account_params
        params.require(:account).permit(
          :data,
          :email,
          note_attributes: [:id, :body],
          shipping_addresses_attributes: [ :id, :firstname, :lastname, :company, :phone, :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id  ],
          billing_addresses_attributes: [ :id, :firstname, :lastname, :company, :phone, :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id  ]
        )
      end

      def load_account
        @account = current_spree_user.vendor_accounts.find_by_id(params[:id])
        @vendor = @account.try(:vendor)
        if @account.nil?
          flash[:error] = "You do not have permission to view the requested account"
          redirect_to accounts_path and return
        end
        @order_search = @account.orders
                                .where(state: ApprovedStates)
                                .ransack(params[:q])
        @order_search.sorts = 'delivery_date DESC' if @order_search.sorts.empty?
        @orders = @order_search.result.page(params[:page])
      end

      def set_address
        # country_id = current_vendor.try(:bill_address).try(:country_id) || Spree::Address.default.country_id # rather set US as default in form

        @account = current_customer.vendor_accounts.find(params[:id])
        @bill_address = @account.bill_address.present? ? @account.bill_address : @account.build_bill_address
        @ship_addresses = @account.shipping_addresses - [@account.default_ship_address]

        if @account.default_ship_address
          @selected_ship_address = @account.default_ship_address
        elsif Spree::Address.where(account_id: @account.id, addr_type: 'shipping').first.present?
          @selected_ship_address = Spree::Address.where(account_id: @account.id, addr_type: 'shipping').first
          @account.update_columns(default_ship_address_id: @selected_ship_address.id)
        else
          @selected_ship_address = @customer.build_ship_address
        end
      end
    end
  end
end
