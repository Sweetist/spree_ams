module Spree
  module Manage

    class VendorsController < Spree::Manage::BaseController
      respond_to :js

      # before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      # before_action :clear_current_order
      # before_action :clear_current_account
      # before_action :ensure_read_permission, only: [:show, :index]
      # before_action :ensure_write_permission, only: [:new, :edit, :create, :update, :destroy]

      def index
        redirect_to manage_vendor_accounts_path
      end

      def new
        redirect_to new_manage_vendor_account_path
      end

      def update_states
        @available_states = Spree::State.where("country_id = ?", params[:country_id]).sort_by &:name
        respond_to do |format|
          format.js {@available_states}
        end
      end

      def actions_router
        if params[:all_customers] == 'true'
          account_ids = []
        elsif params[:company] && params[:company][:customer_accounts_attributes]
          params[:company][:customer_accounts_attributes] ||= {}
          account_ids = params[:company][:customer_accounts_attributes].map {|k, v| v[:id] if v[:action] == '1'}.compact
        end

        case params[:commit]
        when Spree.t(:invite_customers)
          invite_multiple(params[:all_customers], account_ids)
        end

        redirect_to :back
      end


      def invite_email
        #invite specific user based on id
        @customer = Spree::Company.friendly.find(params[:id])
        CustomerMailer.invite_email(current_vendor, @customer).deliver_later
        flash[:success] = "An invitation will be sent shortly"

        redirect_to :back
      end

      def invite_multiple(all_customers, account_ids)
        if all_customers == 'true' || account_ids.present?
          Sidekiq::Client.push(
            'class' => CustomerInviteWorker,
            'queue' => 'mailers',
            'args' => [current_vendor.id, all_customers == "true", account_ids]
            )
          flash[:success] = "Invitations will be sent shortly"
        else
          flash[:error] = "No customers have been selected"
        end
      end

      def destroy
      end

      private
        def customer_params
          params.require(:company).permit(
          :name,
          :email,
          :time_zone,
          ship_address_attributes: [ :id, :firstname, :lastname, :phone, :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id  ],
          bill_address_attributes: [ :id, :firstname, :lastname, :phone, :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id  ]
          )
        end

        def ensure_vendor
          @customer = Spree::Company.find(params[:id])
          unless @customer.vendor_accounts.where(vendor_id: current_vendor.id).present?
            flash[:error] = "You do not have permission to view the page requested"
            redirect_to root_url
          end
        end

        def ensure_read_permission
          if current_spree_user.cannot_read?('basic_options', 'customers')
            flash[:error] = 'You do not have permission to view customers'
            redirect_to manage_path
          end
        end

        def ensure_write_permission
          if current_spree_user.cannot_read?('basic_options', 'customers')
            flash[:error] = "You do not have permission to view customers"
            redirect_to manage_path
          elsif current_spree_user.cannot_write?('basic_options', 'customers')
            flash[:error] = "You do not have permission to edit customers"
            redirect_to manage_accounts_path
          end
        end

    end
  end
end
