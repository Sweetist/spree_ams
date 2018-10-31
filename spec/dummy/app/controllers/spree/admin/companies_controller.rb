module Spree
  module Admin
    class CompaniesController < ResourceController


      def index
        @search = Spree::Company.ransack(params[:q])
        @companies = @search.result.order('name ASC').page(params[:page])
        respond_with(:admin, @companies)
      end

      def new
        @company = Spree::Company.new
        @bill_address = Spree::Address.new(addr_type: 'billing')
      end

      def show
        redirect_to edit_admin_company_path(@company)
      end

      def new
        @company = Spree::Company.new
        render :new
      end

      def create
        @company = Spree::Company.new
        @company.attributes = company_params
        @bill_address = @company.build_bill_address(addr_type: 'billing')
        if @company.save
          flash.now[:success] = flash_message_for(@company, :successfully_created)
          redirect_to edit_admin_company_path(@company)
        else
          render :new
        end
      end

      def reset_email_templates
        @company = Spree::Company.find(params[:company_id])

        overwrite = false
        if @company.setup_email_templates(overwrite)
          flash.now[:success] = "Email templates reset"
        else
          flash.now[:error] = "Something went wrong"
        end
        render :edit
      end

      def setup_email_templates
        @company = Spree::Company.find(params[:company_id])

        overwrite = true
        if @company.setup_email_templates(overwrite)
          flash.now[:success] = "Email templates set up"
        else
          flash.now[:error] = "Something went wrong"
        end
        render :edit
      end

      def update
        if @company.update(company_params)
          flash[:success] = Spree.t(:account_updated)
          redirect_to edit_admin_company_path(@company)
        else
          flash.now[:errors] = @company.errors.full_messages
          render :edit
        end
      end

      def load_default_data
        @company = Spree::Company.friendly.find(params[:id])
        params[:sample_data_options] ||= {}
        @company.load_default_data(params[:sample_data_options])

        flash[:success] = 'Sample data will be loaded shortly.'
        redirect_to :back
      end

      def load_sample_data
        @company = Spree::Company.friendly.find(params[:id])
        params[:sample_data_options] ||= {}
        @company.load_sample_data(params[:sample_data_options])

        flash[:success] = 'Sample data will be loaded shortly.'
        redirect_to :back
      end

      def customer_accounts
        @company = Spree::Company.friendly.find(params[:id])
        @accounts = @company.customer_accounts
                            .includes(:customer)
                            .order(:fully_qualified_name)
        @account_type = 'customer'
        render :accounts
      end
      def vendor_accounts
        @company = Spree::Company.friendly.find(params[:id])
        @accounts = @company.vendor_accounts
                            .includes(:vendor)
                            .order(:fully_qualified_name)
        @account_type = 'vendor'
        render :accounts
      end

      def users
        @company = Spree::Company.friendly.find(params[:id])
        @users = @company.users
      end

      def reset_inventory
        @company = Spree::Company.friendly.find(params[:id])
        @company.reset_inventory!

        flash[:success] = 'Inventory has been reset.'
        redirect_to :back
      end

			protected

			private

      def company_params
				params.require(:company).permit(
          :name,
          :email,
          :order_cutoff_time,
          :currency,
          :slug,
          :time_zone,
          :allow_variants,
          :member,
          :subscription,
          :custom_domain,
          :hide_empty_orders,
          :use_price_lists,
          :only_price_list_pricing,
          :set_visibility_by_price_list,
          :use_variant_text_options,
          bill_address_attributes:
            [ :id, :firstname, :lastname, :company, :phone,
              :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id
            ],
          ship_address_attributes:
            [ :id, :firstname, :lastname, :company, :phone,
              :address1, :address2, :city, :country_id, :state_name, :zipcode, :state_id
            ]
        )
      end
		end
	end
end
