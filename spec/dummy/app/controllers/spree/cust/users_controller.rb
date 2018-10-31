module Spree
  module Cust
    class UsersController < Spree::Cust::CustomerHomeController
      before_action :clear_current_vendor_account
      before_action :load_user, only: [:show, :destroy, :update_account_access, :update_password]
      respond_to :js

      def index
        @company = current_customer
      end

      def new
        @company = current_customer
        @user = @company.users.new
        render :new
      end

      def create
        @company = current_customer
        @user = @company.users.new(user_params)

        @user.spree_roles << Spree::Role.find_by_name('customer')
        if params[:user][:password] != params[:user][:password_confirmation]
          @user.errors[:password] << 'Password does not match Password Confirmation'
        end

        if @user.errors.full_messages.empty? && @user.save
          @company.vendor_accounts.ids.each do |account_id|
            @user.user_accounts.create!(account_id: account_id)
          end
          flash[:success] = "User has been saved."
          redirect_to edit_my_company_user_path(@user, accounts: true)
        else
          flash.now[:errors] = @user.errors.full_messages
          render :new
        end
      end

      def show
        #your code here
      end

      def edit
        @company = current_customer
        @user = params[:id] ? load_user : current_spree_user
        @current_user = current_spree_user.id == @user.id
        if request.host == ENV['DEFAULT_URL_HOST']
          @company_accounts = @user.company.vendor_accounts.includes(:vendor)
        else
          @company_accounts = @user.company.vendor_accounts.where(vendor_id: current_vendor.try(:id)).includes(:vendor)
        end
        render :edit
      end

      def update
        params[:accounts] = nil
        @company = current_customer
        @user = params[:id] ? load_user : current_spree_user
        @current_user = current_spree_user.id == @user.id

        if @user.update(user_params)
          flash[:success] = "Successfully Updated User"
          if @current_user
            redirect_to edit_my_profile_path
          else
            if request.host == ENV['DEFAULT_URL_HOST']
              @company_accounts = @user.company.vendor_accounts.where(vendor_id: current_vendor.try(:id)).includes(:vendor)
            else
              @company_accounts = @user.company.vendor_accounts.includes(:vendor)
            end
            redirect_to edit_my_company_user_path(@user)
          end
        else
          flash.now[:errors] = @user.errors.full_messages
          render :edit
        end
      end

      def destroy
        user_company_name = @user.company.name
        contact_ids = @user.contact_ids
        if @user.destroy
          ContactMailer.notify_deleted_user_email(contact_ids, user_company_name).deliver_later
          flash[:success] = "User has been deleted."
          redirect_to index(accounts: true)
        else
          render :back
        end
      end

      def update_account_access
        params[:user] ||= {}
        account_ids = params[:user][:account_id] || []
        current_user_access_to_accounts = @user.accounts.to_a
        array_holder = current_user_access_to_accounts
        @current_user = current_spree_user.id == @user.id
        #remove intersection of accounts or accounts that haven't changed
        array_holder.each do |e|
          if account_ids.include?(e.id.to_s)
            account_ids = account_ids - [e.id.to_s]
            current_user_access_to_accounts.delete(e)
          end
        end

        #remove ones not selected
        unless current_user_access_to_accounts.blank?
          current_user_access_to_accounts.each do |ca|
            id = Spree::UserAccount.where(user_id: @user.id, account_id: ca.id).first.id
            Spree::UserAccount.destroy(id)
          end
        end

        #add new ones
        account_ids.each do |a|
          ua = Spree::UserAccount.new(user_id: @user.id, account_id: a.to_i)
          ua.save
        end

        @user.assign_contact_accounts

        flash[:success] = "Updated Account Access"
        if @current_user
          redirect_to edit_my_profile_path(accounts: true)
        else
          redirect_to edit_my_company_user_path(@user.id, accounts: true)
        end
      end

      def update_password
        if @user.update_with_password(params.require(:user).permit(:password, :password_confirmation, :current_password))
          sign_in @user, :bypass => true
          flash[:success] = "Password changed successfully"
          redirect_to edit_my_profile_path
        else
          flash[:error] = @user.errors.full_messages.join(', ')
          redirect_to edit_my_profile_path
        end
      end

      private

      def user_params
        params.require(:user).permit(:firstname, :lastname, :email, :phone, :password, :position, :view_images, :customer_admin).tap do |whitelisted|
          whitelisted[:view_images] = params[:user][:view_images]
        end
      end

      def load_user
        @user = current_customer.users.find_by_id(params[:id])
        if @user.nil?
          flash[:error] = 'You do not have permission to view the requested page'
          redirect_to my_company_users_path and return
        end

        @user
      end

    end
  end
end
