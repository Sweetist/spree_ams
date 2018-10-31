module Spree
  module Manage
    class ChartAccountsController < ResourceController
      before_action :ensure_read_permission, only: [:index]
      before_action :ensure_write_permission, only: [:new, :edit, :create, :update]
      before_action :build_accounts_category_hash, only: [:new, :edit, :create, :update]

      def index
        @search = current_spree_user.company.chart_accounts.ransack(params[:q])
        @accounts = @search.result.includes(:chart_account_category).references(:chart_account_category).page(params[:page])

        respond_with(@accounts)
      end

      def new
        @account = current_spree_user.company.chart_accounts.new
        respond_with(@account)
      end

      def create
        @vendor = current_vendor
        if chart_account_params.fetch(:parent_id, nil).present? && chart_account_params.fetch(:chart_account_category_id, nil).blank?
          cat_id = @vendor.chart_accounts.find_by_id(chart_account_params.fetch(:parent_id)).try(:chart_account_category_id)
          params[:chart_account][:chart_account_category_id] ||= cat_id
        end
        @account = current_spree_user.company.chart_accounts.new(chart_account_params)

        if @account.save
          flash[:success] = "New Account has been saved"
          respond_to do |format|
            format.js {}
            format.html {redirect_to manage_chart_accounts_path}
          end
        else
          respond_to do |format|
            format.js do
              flash.now[:errors] = @account.errors.full_messages
            end
            format.html do
              flash.now[:errors] = @account.errors.full_messages
              render :new
            end
          end
        end
      end

      def edit
        @account = current_spree_user.company.chart_accounts.find(params[:id])
        render :edit
      end

      def update
        @account = current_spree_user.company.chart_accounts.find(params[:id])

        if @account.update(chart_account_params)
          flash[:success] = "Account has been updated"
          redirect_to manage_chart_accounts_path
        else
          flash.now[:errors] = @account.errors.full_messages
          render :edit
        end
      end

      def destroy
        @account = current_vendor.chart_accounts.find(params[:id])
        @account.destroy

        respond_to do |format|
          format.js {}
          format.html {redirect_to manage_chart_accounts_path}
        end
      end

      private

      def chart_account_params
        params.require(:chart_account).permit(
          :name,
          :chart_account_category_id,
          :parent_id
        )
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = 'You do not have permission to view company settings'
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = 'You do not have permission to view company settings'
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('company')
          flash[:error] = 'You do not have permission to edit company settings'
          redirect_to manage_chart_accounts_path
        end
      end

      def build_accounts_category_hash
        @acc_cat = {}
        current_vendor.chart_accounts.each do |acc|
          @acc_cat[acc.id] = acc.chart_account_category.name
        end
        return @acc_cat
      end
    end
  end
end
