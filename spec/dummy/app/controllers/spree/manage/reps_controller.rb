module Spree
  module Manage
    class RepsController < Spree::Manage::BaseController

      before_action :ensure_read_permission, only: [:index, :show]
      before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]
      def index
        @vendor = current_vendor
        @reps = @vendor.reps.includes(accounts: :customer)
                            .page(params[:page])

        render :index
      end

      def new
        @vendor = current_vendor
        @rep = @vendor.reps.new
      end

      def create
        @vendor = current_vendor
        @rep = @vendor.reps.new(rep_params)
        if @rep.save
          flash[:success] = 'New sales rep added'
          redirect_to manage_reps_path
        else
          flash.now[:errors] = @rep.errors.full_messages
          render :new
        end
      end

      def show
        redirect_to edit_manage_rep_path(params[:id])
      end

      def edit
        @vendor = current_vendor
        @rep = @vendor.reps.find(params[:id])

        render :edit
      end

      def update
        @vendor = current_vendor
        @rep = @vendor.reps.find(params[:id])
        if @rep.update(rep_params)
          flash[:success] = 'Sales rep updated'
          redirect_to manage_reps_path
        else
          flash.now[:errors] = @rep.errors.full_messages
          render :edit
        end
      end

      def destroy
        @vendor = current_vendor
        @rep = @vendor.reps.find(params[:id])
        if @rep.destroy
          flash[:success] = 'Sales rep deleted'
        else
          flash[:error] = 'Could not delete sales rep'
        end

        redirect_to manage_reps_path
      end

      private

      def rep_params
        params.require(:rep).permit(:name, :initials)
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
          redirect_to manage_reps_path
        end
      end

    end
  end
end
