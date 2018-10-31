module Spree
  module Manage
    class AccountPaymentsController < Spree::Manage::BaseController
      respond_to :js, :html
      before_action :ensure_vendor, only: %i[show edit update destroy]
      before_action :ensure_read_permission, only: %i[index show]
      before_action :ensure_write_permission, only: %i[new edit create
                                                       update destroy]
      before_action :load_vendor, except: %i[index data_table_json
                                             create_refund fire update destroy]

      def index
        @account_payments = current_vendor.account_payments

        @default_statuses = %w[pending processing completed void failed invalid]

        params[:q] ||= {}
        params[:q][:state_eq_any] = @default_statuses if params[:q][:state_eq_any].blank?
        @search = @company.account_payments
                          .order('completed_at DESC').ransack(params[:q])
        respond_to do |format|
          format.html
          format.json { render json: data_table_json(view_context) }
        end
      end

      def data_table_json(view_context)
        SpreeAccountPaymentsDatatable
          .new(view_context, vendor: current_company,
                             user: current_spree_user,
                             ransack_params: params[:q])
      end

      def new
        if params[:order_id].present?
          @order = Spree::Order.friendly.find(params[:order_id])
          @account = @order.account
          @account_payment = @vendor.account_payments.new(
            payment_date: DateHelper.sweet_today(@vendor.time_zone),
            account_id: @account.id,
            amount: @order.remaining_balance
          )
          @payment_methods = @vendor.payment_methods.available_on_back_end
          @orders = [@order]
          @acc_orders = @vendor.sales_orders.invoiceable
                               .where(account: @account)
                               .where.not(id: @order.id)
                               .where(payment_state: 'balance_due')
                               .order(due_date: :asc, delivery_date: :asc)
          @inner_payment_method = Spree::AccountPayment.inner_payment_method
          @orders = Kaminari.paginate_array(@orders + @acc_orders)
                            .page(params[:page]).per(10)
          @account_payment.payments.build
          render :new_with_order
        else
          @account_payment = @vendor.account_payments.new(
            payment_date: DateHelper.sweet_today(@vendor.time_zone)
          )
          @payment_methods = @vendor.payment_methods.available_on_back_end
        end
        @account_payment.payments.build
      end

      def new_payment
        @payment_methods = @vendor.payment_methods.available_on_back_end
        @amount = params[:amount]
        @account = @vendor.customer_accounts.find_by(id: params[:account_id])
        @payment_method = @vendor.payment_methods.active
                                 .find(params[:payment_method_id])
        respond_to do |format|
          format.js
        end
      end

      def vendor_accounts
        @account_id = params[:account_id]
        @account = @vendor.customer_accounts.find_by(id: @account_id)
        @orders = Kaminari.paginate_array(@vendor.sales_orders.invoiceable
                          .where(account: @account)
                          .where(payment_state: 'balance_due')
                          .order(due_date: :asc, delivery_date: :asc))
                          .page(params[:page]).per(10)
        @inner_payment_method = Spree::AccountPayment.inner_payment_method
        @credit_memos = @account.credit_memos
        @account_payment = @vendor.account_payments.new(
          payment_date: DateHelper.sweet_today(@vendor.time_zone)
        )
        respond_to do |format|
          format.js
        end
      end

      def new_refund
        @refund_reasons ||= RefundReason.active.all
        @account_payment = Spree::AccountPayment.friendly.find(params[:id])
        @refund = @account_payment.refunds.new(amount: @account_payment.amount)
        @orders = @account_payment.orders
        respond_to do |format|
          format.js
        end
      end

      def create_refund
        @account_payment = Spree::AccountPayment.friendly.find(params[:id])
        begin
          if @account_payment.create_refund(refund_params)
            flash[:success] = "Refund for #{@account_payment.display_number} created"
            respond_to do |format|
              format.html { redirect_to redirect_destination }
              format.js { render js: "window.location = '#{redirect_destination}';" }
            end
          else
            flash.now[:errors] = @account_payment.errors.full_messages
            redirect_to :edit
          end
        rescue Spree::Core::GatewayError => e
          error_message = e.message
          flash.now[:errors] = [error_message]
          respond_to do |format|
            format.js { render action: 'create_refund' }
          end
        end
      end

      def create
        format_form_date_field(:account_payment, :payment_date, @vendor)
        @account_payment = @vendor.account_payments
                                  .new(account_payment_params)
        revert_date_to_view_format(:account_payment, :payment_date, @vendor)
        if @account_payment.payment_method.source_required? &&
           params[:card].present? && params[:card] != 'new'
          @account_payment.source = @account_payment.payment_method
                                                    .payment_source_class
                                                    .find_by_id(params[:card])
        end
        @account_payment.orders_amount_sum = orders_amount_sum
        begin
          @account_payment.save
          @account_payment.process_and_capture unless @account_payment.errors.any?
          if @account_payment.errors.any?
            flash.now[:errors] = @account_payment.errors.full_messages
            render :new
          else
            add_payments
            add_credit_memos
            flash[:success] = 'New account payment saved'
            respond_to do |format|
              format.html { redirect_to manage_account_payments_path }
              format.js { render js: "window.location = '#{manage_account_payments_path}';" }
            end
          end
        rescue Spree::Core::GatewayError => e
          error_message = if e.message == 'Your card number is incorrect.'
                            'Card number is invalid'
                          else
                            e.message
                          end
          flash.now[:errors] = [error_message]
          render :new
        end
      end

      def show
        @payment = @account_payment
        respond_to do |format|
          format.html { redirect_to edit_manage_account_payment_url(params[:id]) }
          format.js
        end
      end

      def edit
        @account_payment = Spree::AccountPayment.friendly.find(params[:id])
        @account = @account_payment.account
        @payment_methods = current_vendor.payment_methods.available_on_back_end
        @orders = Kaminari.paginate_array(orders_for_edit(@account_payment,
                                                          @vendor, @account))
                          .page(params[:page]).per(10)
        @payments = @account_payment.payments.page(params[:page]).per(10)
        @inner_payment_method = Spree::AccountPayment.inner_payment_method
        @credit_memos = credit_memos_for_edit(@account_payment, @vendor, @account)
      end

      def fire
        params[:e] = 'capture' if params[:account_payment].present?
        @account_payment = Spree::AccountPayment.friendly.find(params[:id])

        @account_payment.orders_amount_sum = orders_amount_sum
        return unless event = params[:e] and @account_payment.payment_source

        # Because we have a transition method also called void,
        # we do this to avoid conflicts.
        event = 'void_transaction' if event == 'void'
        if @account_payment.send("#{event}!")
          flash[:success] = Spree.t(:payment_updated)
        else
          flash[:error] = Spree.t(:cannot_perform_operation)
        end
      rescue Spree::Core::GatewayError => ge
        flash[:error] = ge.message.to_s
      ensure
        redirect_to redirect_destination
      end

      def update
        if params.fetch(:account_payment, {}).fetch(:payment_date, nil).present?
          format_form_date_field(:account_payment, :payment_date, @vendor)
        end
        begin
          if @account_payment.editable?
            @account_payment.remove_credit_memos!
            @account_payment.void_child_payments!
            @account_payment.orders_amount_sum = orders_amount_sum
            @account_payment.update(account_payment_params)
            @account_payment.process_and_capture unless @account_payment.errors.any?
          else
            @account_payment.cannot_edit_error
          end
          if params.fetch(:account_payment, {}).fetch(:payment_date, nil).present?
            revert_date_to_view_format(:account_payment, :payment_date, @vendor)
          end
          if @account_payment.errors.any?
            flash[:errors] = @account_payment.errors.full_messages
            redirect_to :back
          else
            add_payments
            add_credit_memos
            return fire if params[:account_payment][:edit_with_capture] == '1'
            flash[:success] = "Payment #{@account_payment.display_number} updated"
            respond_to do |format|
              format.html { redirect_to manage_account_payments_path }
              format.js { render js: "window.location = '#{manage_account_payments_path}';" }
            end
          end
        rescue Spree::Core::GatewayError => e
          error_message = if e.message == 'Your card number is incorrect.'
                            'Card number is invalid'
                          else
                            e.message
                          end
          flash.now[:errors] = [error_message]
          @account = @account_payment.account
          @payment_methods = current_vendor.payment_methods.available_on_back_end
          @orders = Kaminari.paginate_array(orders_for_edit(@account_payment,
                                                            @vendor, @account))
                            .page(params[:page]).per(10)
          @payments = @account_payment.payments.page(params[:page]).per(10)
          @inner_payment_method = Spree::AccountPayment.inner_payment_method
          @credit_memos = credit_memos_for_edit(@account_payment, @vendor, @account)
          render :edit
        end
      end

      def destroy; end

      private

      def add_credit_memos
        return unless credit_memos_attributes && @account_payment
        @account_payment.add_credit_memos(credit_memos_attributes)
      end

      # uses for add child payments in Sidekiq when create
      # to resolve timeout issues
      def add_payments
        return unless payments_attributes && @account_payment
        if Rails.env.test?
          @account_payment.add_and_process_child_payments(payments_attributes)
        else
          AccountPaymentProcessWorker
            .perform_async(@account_payment.id, payments_attributes)
        end
      end

      def orders_amount_sum
        if payments_attributes.present?
          payments_attributes.inject(0) { |sum, pa| sum + pa['amount'].to_d }
        else
          @account_payment.payments
                          .where(state: %i[checkout completed]).sum(:amount)
        end
      end

      def credit_memos_attributes
        return [] unless params[:credit_memos_attributes]
        pa = params[:credit_memos_attributes]
        pa.delete_if { |t| !t.key?('check') }
        pa
      end

      def payments_attributes
        return [] unless params[:payments_attributes]
        pa = params[:payments_attributes]
        pa.delete_if { |t| !t.key?('check') }
        pa
      end

      def add_source_params_to_account_payment
        return unless params[:account_payment] && params[:payment_source]
        source_params = params
                        .delete(:payment_source)[params[:account_payment]\
                                                [:payment_method_id]]
        if source_params[:expiry_month].to_s.length < 2
          source_params[:expiry_month] = "0#{source_params[:expiry_month]}"
        end
        source_params[:expiry] = "#{source_params[:expiry_month]}/#{source_params[:expiry_year]}"
        source_params[:account_id] = params[:account_payment][:account_id]
        params[:account_payment][:source_attributes] = source_params
      end

      def account_payment_params
        params[:account_payment][:last_ip_address] = current_spree_user
                                                     .try(:current_sign_in_ip)
        add_source_params_to_account_payment
        params.require(:account_payment).permit(
          :id, :amount, :account_id, :vendor_id, :credit_to_apply,
          :payment_method_id, :memo, :txn_id, :last_ip_address,
          :payment_date,
          source_attributes: %i[number expiry verification_value
                                cc_type name account_id zip]
        )
      end

      def refund_params
        pa = params[:account_payment][:payments_attributes]
        pa.delete_if { |t| !t.key?('check') } if pa
        params.require(:account_payment).permit(
          :id, :amount, :refund_reason_id,
          payments_attributes: %i[order_id amount]
        )
      end

      def redirect_destination
        if request.referer.include?('orders')
          order_id = request.referer.split('/')[5]
          order = current_vendor.sales_orders.friendly.find(order_id)
          edit_manage_order_path(order)
        else
          manage_account_payments_path
        end
      end

      def ensure_vendor
        @account_payment = Spree::AccountPayment.friendly.find(params[:id])
        @vendor = current_vendor
        return if current_vendor.id == @account_payment.try(:vendor_id)

        flash[:error] = "You don't have permission to view the requested page"
        redirect_to root_url
      end

      def ensure_read_permission
        return true if current_spree_user.can_read?('payments', 'order')
        flash[:error] = 'You do not have permission to view payments'
        redirect_to manage_path
      end

      def ensure_write_permission
        return true if current_spree_user.can_write?('payments', 'order')
        flash[:error] = 'You do not have permission to edit payments'
        redirect_to manage_path
      end

      def orders_for_edit(account_payment, vendor, account)
        orders = account_payment.orders_for_edit
        return orders unless account_payment.editable?
        acc_orders = vendor.sales_orders.invoiceable
                           .where(account: account)
                           .where.not(id: orders.ids)
                           .where(payment_state: 'balance_due')
                           .order(due_date: :asc, delivery_date: :asc)
        orders + acc_orders
      end

      def credit_memos_for_edit(account_payment, vendor, account)
        credit_memos = account_payment.credit_memos
        return credit_memos unless account_payment.editable?
        acc_credit_memos = vendor.credit_memos
                                 .where(account: account)
                                 .where.not(id: credit_memos.ids)
                                 .where.not(amount_remaining: 0)
                                 .order(txn_date: :asc, created_at: :asc)
      end

      def load_vendor
        @vendor = current_vendor
      end
    end
  end
end
