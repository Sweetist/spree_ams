module Spree
  module Manage

    class CustomersController < Spree::Manage::BaseController
      respond_to :js

      before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      before_action :clear_current_order
      before_action :clear_current_account, only: [:index, :show, :edit, :new]
      before_action :ensure_read_permission, only: [:show, :index]
      before_action :ensure_write_permission, only: [:new, :edit, :create, :update, :destroy]

      def index
        redirect_to manage_accounts_path
      end

      def new
        redirect_to new_manage_account_path
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
        when Spree.t(:export_all_customers)
          redirect_to download_csv_manage_customers_path and return
        end

        redirect_to :back
      end


      def invite_email
        # invite specific user based on id
        @account = Spree::Account.find_by_id(params[:account_id])

        if @account.valid_emails.present?

          # if account has valid emails,
          # let's go through each email address in the email field on the account,
          # create contacts for them, and then invite the contacts to use Sweet

          @account.valid_emails.uniq.each do |email|

            contact = current_vendor.contacts.find_or_initialize_by(email: email)

            if contact.id
              # contact already exists
              # for now, we are inviting the existing contact if the vendor decides to click "invite customer" again
              # may be a good idea later to check if customer has been invited already or is already using Sweet

              contact = current_vendor.contacts.find_by_email(email)
              ContactMailer.invite_email(current_vendor, contact).deliver_later
              flash[:success] = "An invitation will be sent shortly"
            elsif contact.save
              contact.account_ids = [@account.id] # it's a new contact so we need to set up the account relationship
              ContactMailer.invite_email(current_vendor, contact).deliver_later
              flash[:success] = "An invitation will be sent shortly"
            else
              # contact did not save for some reason so let's just have them call us
              flash[:warning] = "We are currently unable to invite your customer, please contact help@getsweet.com for assistance"
            end

          end
        else
          # No emails on file (@account.valid_emails.empty? == true)
          flash[:error] = "There are no valid email addresses on file for the account. Please add a valid email to the account or invite a contact instead."
        end

        redirect_to :back
      end

      def invite_multiple(all_customers, account_ids)
        if all_customers == 'true' || account_ids.present?
          Sidekiq::Client.push(
            'class' => CustomerInviteWorker,
            'queue' => 'mailers',
            'args' => [current_vendor.id, all_customers == "true", account_ids]
            )
          flash[:success] = "Invitations will be sent shortly to customers with valid emails on file"
        else
          flash[:error] = "No customers have been selected"
        end
      end

      def download_csv
        options = {}
        customers = current_vendor.customer_accounts.includes(:customer).order(fully_qualified_name: 'ASC')
        send_data customers.to_csv(options), filename: "all_customers_#{Time.current.in_time_zone(current_vendor.try(:time_zone)).strftime('%Y-%m-%d')}.csv", type: 'text/csv', disposition: 'inline'
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
