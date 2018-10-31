module Spree
  module Manage
    class ContactsController < Spree::Manage::BaseController
      respond_to :js, :html
      before_action :set_contact, only: [:show, :edit, :update, :destroy, :invite_email, :mark_invited]

      def index
        @vendor = current_vendor
        params[:q] ||= {}
        @open_search = params[:q].except('full_name_cont','s').any?{|k,v| v.present?}
        @search = current_vendor.contacts.ransack(params[:q])
        @contacts = @search.result.includes(:accounts).order('full_name ASC').page(params[:page])
      end

      def show
        @customer_accounts = current_vendor.customer_accounts
        @contact_account_ids = @contact.account_ids
        @invite_button_enabled = @contact_account_ids.count > 0 && @contact.email.present?
      end

      def new
        @contact_account_ids = []
        @customer_accounts = current_vendor.customer_accounts.order('fully_qualified_name ASC')
        @contact = current_vendor.contacts.new
        @contact_account_ids = @contact.account_ids
      end

      def edit
        @customer_accounts = current_vendor.customer_accounts.order('fully_qualified_name ASC')
        @contact_account_ids = @contact.account_ids
      end

      def search
        redirect_to manage_account_contacts_path, flash: { search: search_params }
      end

      def create
        account_ids = contact_params[:account_ids].reject(&:empty?)
        @contact = current_vendor.contacts.new(contact_params.except(:account_ids))
        @customer_accounts = current_vendor.customer_accounts
        selected_customer_accounts = @customer_accounts.where(id: account_ids)

        @contact_account_ids = account_ids
        # ensure accounts selected are all from the same customer company

        if @contact.valid_account_ids?(account_ids) && @contact.save
          @contact.account_ids = account_ids

          # go through customer accounts, and, if this is the first contact for any of them,
          # set this contact as the primary contact on them
          selected_customer_accounts.each do |customer|
            if customer.contacts.count == 1
              customer.primary_cust_contact_id = @contact.id
              customer.save
            end
          end

          respond_with do |format|
            format.html do
              flash[:success] = 'Contact was successfully created.'
              redirect_to manage_account_contacts_url
            end
          end
        else
          respond_with do |format|
            format.html do
              flash.now[:errors] = @contact.errors.full_messages + @contact.contact_accounts.map{|ca|ca.errors.full_messages}
              render :new
            end
          end
        end
      end

      def update
        account_ids = contact_params[:account_ids].reject(&:empty?)
        @customer_accounts = current_vendor.customer_accounts
        selected_customer_accounts = @customer_accounts.where(id: account_ids)
        @contact_account_ids = account_ids

        if @contact.valid_account_ids?(account_ids) && @contact.update(contact_params)
          # go through customer accounts, and, if this is the first contact for any of them,
          # set this contact as the primary contact on them
          selected_customer_accounts.each do |customer|
            if customer.contacts.count == 1
              customer.primary_cust_contact_id = @contact.id
              customer.save
            end
          end

          @contact.account_ids = contact_params[:account_ids]
          redirect_to manage_account_contacts_url
          flash[:success]='Contact was successfully updated.'
        else
          flash.now[:errors]= @contact.errors.full_messages
          render :edit
        end
      end

      def destroy
        if @contact.destroy
          redirect_to manage_account_contacts_url
          flash[:success]='Contact was deleted.'
        else
          redirect_to :back
          flash.now[:errors] = @contact.errors.full_messages
        end
      end

      def invite_email
        if request.referer.include?("customer")
          referer_path = request.referer + "#contacts_tab"
        else
          referer_path = request.referer
        end

        @contacts = current_vendor.contacts.page(params[:page])
        # setting @user to be the user linked to invited contact
        @user = Spree::User.find_by_email(@contact.email)
        # setting @company to be contact's linked customer company
        @company = Spree::Company.find_by_id(@contact.accounts.first.try(:customer_id))
        if @user.nil?
          ContactMailer.invite_email(current_vendor, @contact).deliver_later
          @contact.update(invited_at: Time.current)
          flash[:success] = "An invitation will be sent shortly"
          redirect_to referer_path
        else
          # check if invited contact's user is linked to contact's first customer company
          if @company && (@user.try(:company_id) == @company.try(:id))
            # if invited contact's user IS linked, then:
            # remind user about invitation to begin using B2B portal

            @contact.update(invited_at: Time.current) #will update user accounts
            ContactMailer.invite_email(current_vendor, @contact).deliver_later
            flash[:success] = "An invitation will be sent shortly"
            redirect_to referer_path
          else
            # if invited contact's user is linked to a different company, then:
            # link and send notification that they're linked and can use the B2B portal
            # or ask if user wants to accept link and then if so, setup link

            ContactMailer.contact_conflict_email(current_vendor, @contact).deliver_later
            flash[:warning] = "The contact you've invited appears to registered to a different company.
              Sweet support has been notified and will contact you within one business day. For any questions, please contact help@getsweet.com."
            redirect_to referer_path
          end
        end
      end

      def mark_invited
        @contact.invited_at = Time.current
        flash[:success] = 'Contact updated'
        respond_to do |format|
          format.html do

            unless @contact.save
              flash[:success] = nil
              flash[:errors] = @contact.errors.full_messages
            end
            redirect_to :back
          end

          format.js do
            unless @contact.save
              flash[:success] = nil
              flash.now[:errors] = @contact.errors.full_messages
            end
            render :mark_invited
          end
        end
      end

      def actions_router
        if params[:all_contacts] == 'true'
          contact_ids = []
        elsif params[:company] && params[:company][:contacts_attributes]
          params[:company][:contacts_attributes] ||= {}
          contact_ids = params[:company][:contacts_attributes].map {|k, v| v[:id] if v[:action] == "1"}.compact
        end

        case params[:commit]
        when Spree.t(:invite_selected_contacts)
          invite_multiple(params[:all_contacts], contact_ids)
        when Spree.t(:export_contacts)
          redirect_to download_csv_manage_account_contacts_path and return
        end

        redirect_to :back
      end

      def download_csv
        vendor = current_company
        contacts = vendor.contacts.includes(:user, :accounts)
        update_headers(vendor)
        self.response_body = Enumerator.new do |yielder|
          yielder << line_head.to_csv
          contacts.each do |contact|
            yielder << line_base(contact, vendor).to_csv
          end
        end
        response.status = 200
      end

      private

      def contact_params
        params.require(:contact).permit(
          :first_name,
          :last_name,
          :position,
          :phone,
          :company_id,
          :notes,
          :email,
          :addresses,
          :account_ids => [])
      end

      def update_headers(vendor)
        headers.delete('Content-Length')
        headers['Cache-Control'] = 'no-cache'
        headers['Content-Type'] = 'text/csv'
        headers['Content-Disposition'] = "attachment; filename=\"#{Time.current.in_time_zone(vendor.try(:time_zone)).strftime('%Y-%m-%d')}_contacts_export.csv\""
        headers['X-Accel-Buffering'] = 'no'
      end

      def line_head
        ['First Name', 'Last Name', 'Email', 'Phone', 'Company Name',
         'Position', 'Account', 'Invited At', 'Last Sign In',
         'Created At', 'Updated At']
      end

      def line_base(contact, vendor)
        [
          contact.first_name,
          contact.last_name,
          contact.email,
          contact.phone,
          contact.company_name,
          contact.position,
          contact.accounts.map(&:fully_qualified_name).join(', '),
          DateHelper.display_vendor_date_time_format( contact.invited_at,
                                                      vendor.date_format,
                                                      vendor.time_zone ),
          DateHelper.display_vendor_date_time_format( contact.user.try(:last_sign_in_at),
                                                      vendor.date_format,
                                                      vendor.time_zone ),
          DateHelper.display_vendor_date_time_format( contact.created_at,
                                                      vendor.date_format,
                                                      vendor.time_zone ),
          DateHelper.display_vendor_date_time_format( contact.updated_at,
                                                      vendor.date_format,
                                                      vendor.time_zone )
        ]
      end

      def set_contact
        @contact = current_vendor.contacts.find_by_id(params[:id]) rescue nil
        unless @contact.present?
          flash[:error] = "You do not have permission to view the requested page."
          redirect_to manage_account_contacts_path
        end
      end

      def invite_multiple(all_contacts, contact_ids)
        if all_contacts == 'true' || contact_ids.present?
          Sidekiq::Client.push(
            'class' => ContactInviteWorker,
            'queue' => 'mailers',
            'args' => [current_vendor.id, all_contacts == "true", contact_ids]
            )
          flash[:success] = "Invitations will be sent to contacts who are associated with a customer and have an email on file"
        else
          flash[:error] = "No contacts have been selected"
        end
      end

    end
  end
end
