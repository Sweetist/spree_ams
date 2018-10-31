module Spree
  class SignUpsController < ApplicationController

  layout 'session'

    def new
      @contact = Spree::Contact.find_by(id: params[:id])
      if @contact
        @user = Spree::User.new(
          firstname: @contact.first_name,
          lastname: @contact.last_name,
          email: @contact.email,
          phone: @contact.phone,
          position: @contact.position)
      end

      if @contact
        if params[:vendor].present?
          @vendor = @contact.try(:company)
          session[:spree_user_return_to] = "/shop/#{params[:vendor]}"
        end
        render :new
      elsif params[:vendor].present?
        session[:spree_user_return_to] = "/shop/#{params[:vendor]}"
        flash[:error] = 'The link provided is no longer valid. Please try submitting the request access form below or contact them directly.'
        redirect_to request_access_path
      else
        flash[:error] = 'The link provided is no longer valid. If you were invited by a vendor please contact them directly.'
        redirect_to login_path
      end
    end

    def create
      @contact = Spree::Contact.find(user_params[:id])
      @contact.touch(:invited_at) if @contact.invited_at.nil?
      # check if all the customer_id all match they have to all match
      @company = @contact.accounts.first.try(:customer)

      if @company
        @user = Spree::User.find_by_email(user_params[:email])
        user_exists = @user.present?
        @user ||= @company.users.new(user_params.except(:id))
        @user.spree_roles << Spree::Role.find_by_name('customer') unless @user.is_customer?

        if @user.company_id == @company.id

          if user_exists || @user.save # check persisted? to prevent callback before assigning accounts
            flash[:success] = "Your account has been created."
            first_name = @contact.first_name.blank? ? user_params[:firstname] : @contact.first_name
            last_name = @contact.last_name.blank? ? user_params[:lastname] : @contact.last_name
            @contact.reload.update(
              first_name: first_name,
              last_name: last_name,
              email: user_params[:email],
              phone: user_params[:phone],
              position: user_params[:position]
            ) # updating contact will trigger callback to assign accounts

            @user.update(user_params.except(:id)) if user_exists

            sign_in @user
            redirect_to root_path
          else
            flash[:errors] = @user.errors.full_messages
            redirect_to new_sign_up_url(id: @contact.id)
          end
        else
          flash[:error] = "Sorry, we are unable to create your account. Your email is tied to a different company. Please contact help@getsweet.com or the vendor who has invited you for assistance."
          redirect_to new_sign_up_url(id: @contact.id)

          # contact already belongs to a different company
          # notify airbrake so we don't lose track of this
          Airbrake.notify(
            error_message: "Invited contact is tied to a different company",
            error_class: "SignUpsController",
            parameters: {
              params: user_params,
              contact_email: @contact.email,
              contact: @contact,
              user: @user,
              company: @company
            }
          )
        end
      else
        flash[:error] = "An error has occurred and we cannot verify your account. Please contact help@getsweet.com for assistance."
        redirect_to new_sign_up_url(id: @contact.id)
      end
    end

    private

    def user_params
      params.require(:user).permit(:id, :firstname, :lastname, :email, :phone, :password, :password_confirmation, :position)
    end

  end
end
