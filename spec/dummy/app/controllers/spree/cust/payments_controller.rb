module Spree
  module Cust
    class PaymentsController < Spree::Cust::CustomerHomeController
      include Spree::Backend::Callbacks
      respond_to :js
      # before_action :ensure_vendor, only: [:show, :edit, :update, :destroy]
      # before_action :ensure_read_permission, only: [:index, :show]
      # before_action :ensure_write_permission, only: [:new, :edit, :create, :update, :destroy]

      before_action :load_data
      before_action :load_payment, except: [:create, :new, :index]
      before_action :load_order, only: [:create, :new, :index, :fire]
      before_action :validate_payment_method_provider, only: :create

      def index
        @payments = @order.payments.includes(:refunds => :reason)
        @refunds = @payments.flat_map(&:refunds)
        redirect_to new_order_payment_url(@order) if @payments.empty?
      end

      def new
        @payment = @order.payments.build
      end

      def create
        invoke_callbacks(:create, :before)
        @account_payment ||= @order.account_payments.new(payment_params)
        @payment ||= Spree::Payment.new(payment_params) #need this if there are any failures
        if @account_payment.payment_method.source_required? && params[:card].present? and params[:card] != 'new'
          @account_payment.source = @account_payment.payment_method.payment_source_class.find_by_id(params[:card])
        end

        @account_payment.account = @order.account
        @account_payment.customer = @order.customer
        @account_payment.vendor = @order.vendor
        @account_payment.last_ip_address = current_spree_user.try(:current_sign_in_ip)
        @account_payment.orders_amount_sum = orders_amount_sum

        if @order.final_payments_pending?
          flash.now[:errors] = ['Payments are already pending for this order.']
          respond_to do |format|
            format.html { render :new and return }
            format.js { render :create and return }
          end
        end

        if @order.paid?
          flash.now[:errors] = ['This order is already paid.']
          respond_to do |format|
            format.html { render :new and return }
            format.js { render :create and return }
          end
        end

        begin
          @account_payment.save
          if @account_payment.errors.any? \
            || !@order.valid_for_customer_submit?({skip_payment: true})
            invoke_callbacks(:create, :fails)
            flash.now[:errors] = @account_payment.errors.full_messages + @order.errors_including_line_items
            respond_to do |format|
              format.html { render :new }
              format.js {}
            end
          else
            invoke_callbacks(:create, :after)
            @order.channel = Spree::Company::B2B_PORTAL_CHANNEL if @order.state == 'cart'
            ActiveRecord::Base.transaction do
              while States[@order.state] < States['complete'] && @order.next; end
              @account_payment.process_and_capture if @order.completed? && @account_payment.checkout?
              add_payments({async: false})
            end
            @order.update_columns(user_id: current_spree_user.try(:id)) if @order.user_id.nil?
            flash[:success] = 'Payment created'
            @order.reload
            if params[:commit] == Spree.t(:submit_order)
              respond_to do |format|
                format.html { redirect_to success_order_path(@order) }
                format.js { render js: "window.location.href = '" + success_order_path(@order) + "'" }
              end
            else
              respond_to do |format|
                format.html { redirect_to edit_order_path(@order) }
                format.js { render js: 'window.location.reload();' }
              end
            end
          end
        rescue Spree::Core::GatewayError => e
          invoke_callbacks(:create, :fails)
          @account_payment.destroy!
          error_message = e.message == 'Your card number is incorrect.' ? 'Card number is invalid' : e.message
          flash.now[:errors] = [error_message]
          render :new
        end
      end

      def update
         if !@payment.editable?
           render 'update_forbidden', status: 403
         elsif @payment.amount = params["amount"]
           @payment.save
           respond_to do |format|
             format.json { render json: @payment }
           end
         else
           invalid_resource!(@payment)
         end
       end

      def show
      end

      private

      def orders_amount_sum
        return 0 unless payments_attributes

        payments_attributes.inject(0) { |sum, pa| sum + pa['amount'].to_d }
      end

      def payments_attributes
        [{ 'order_id' => @order.id, 'amount' => @account_payment.amount }]
      end

      # uses for add child payments in Sidekiq when create
      # to resolve timeout issues
      def add_payments(options = {})
        opts = {async: true}
        opts.merge!(options)
        return unless payments_attributes && @account_payment
        @account_payment.reload
        if Rails.env.test? || opts[:async]
          @account_payment.add_and_process_child_payments(payments_attributes)
        else
          AccountPaymentProcessWorker
            .perform_async(@account_payment.id, payments_attributes)
        end
      end

      def payment_params
        if params[:payment] and params[:payment_source] && source_params = params.delete(:payment_source)[params[:payment][:payment_method_id]]
          if source_params[:expiry_month].to_s.length < 2
            source_params[:expiry_month] = "0#{source_params[:expiry_month]}"
          end
          source_params[:expiry] = "#{source_params[:expiry_month]}/#{source_params[:expiry_year]}"
          source_params[:account_id] = @order.try(:account_id)
          params[:payment][:source_attributes] = source_params
        end
        params.require(:payment).permit(permitted_payment_attributes)
      end

      def load_data
        @amount = params[:amount] || load_order.total
        @payment_methods = current_vendor.payment_methods.available_on_front_end.active
        if @payment and @payment.payment_method
          @payment_method = @payment.payment_method
        else
          @payment_method = @payment_methods.first
        end
      end

      def load_order
        @order = current_customer.purchase_orders.friendly.find(params[:order_id])
        unless @order.present?
          flash[:error] = "You do not have permission to view the requested page"
          redirect_to orders_path and return
        end
        @order
      end

      def load_payment
        @payment = current_vendor.sales_payments.friendly.find(params[:id])
      end

      def model_class
        Spree::Payment
      end

      def validate_payment_method_provider
        unless params[:payment_method]
          payment_type = current_vendor.payment_methods.active.find_by_id(params["payment"]["payment_method_id"]).type
        else
          payment_type = params[:payment_method][:type]
        end
        valid_payment_methods = Sweet::Application.config.x.payment_methods.map(&:to_s)
        if !valid_payment_methods.include?(payment_type)
          flash[:error] = Spree.t(:invalid_payment_provider)
          redirect_to :back
        end
      end

    end
  end
end
