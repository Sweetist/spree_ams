class Spree::Manage::CreditMemosController < Spree::Manage::BaseController
  before_action :set_vendor
  before_action :set_credit_memo,
                only: %i[show edit update destroy]

  respond_to :js

  def index
    @credit_memos = @vendor.credit_memos.all
    params[:q] ||= {}
    params[:q][:state_eq_any] = @default_statuses if params[:q][:state_eq_any].blank?
    @search = @vendor.credit_memos
                     .order('completed_at DESC').ransack(params[:q])
    respond_to do |format|
      format.html
      format.json { render json: data_table_json(view_context) }
    end
  end

  def data_table_json(view_context)
    SpreeCreditMemosDatatable
      .new(view_context, vendor: current_company,
                         user: current_spree_user,
                         ransack_params: params[:q])
  end

  def show
  end

  def new
    @credit_memo = @vendor.credit_memos.new
    @search = @credit_memo.credit_line_items.ransack(params[:q])
    @line_items = @search.result.page(params[:page])

    @customer_accounts = @vendor.customer_accounts.active.order('fully_qualified_name ASC')
  end

  def edit
    @search = @credit_memo.credit_line_items.ransack(params[:q])
    @line_items = @search.result.page(params[:page])
    @account = @credit_memo.account

    @customer_accounts = @vendor.customer_accounts.active.order('fully_qualified_name ASC')
    @shipping_methods = @account.vendor.shipping_methods
  end

  def create
    format_form_date_field(:credit_memo, :txn_date, @vendor)
    @credit_memo = @vendor.credit_memos.new(credit_memo_params)

    respond_to do |format|
      if @credit_memo.save
        flash[:success] = 'Credit memo was successfully created.'
        format.html do
          redirect_to edit_manage_credit_memo_path(@credit_memo)
        end
        format.js { render js: "window.location = '#{edit_manage_credit_memo_path(@credit_memo)}';" }
        format.json { render :show, status: :created, location: @credit_memo }
      else
        flash.now[:errors] = @credit_memo.errors.full_messages
        @search = @credit_memo.credit_line_items.ransack(params[:q])
        @line_items = @search.result.page(params[:page])

        @customer_accounts = @vendor.customer_accounts.active.order('fully_qualified_name ASC')
        format.html { render :new }
        format.json { render json: @credit_memo.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      format_form_date_field(:credit_memo, :txn_date, @vendor)
      if @credit_memo.update(credit_memo_params)
        flash[:success] = 'Credit memo was successfully updated.'
        format.html do
          redirect_to edit_manage_credit_memo_path(@credit_memo)
        end
        format.js { render js: "window.location = '#{edit_manage_credit_memo_path(@credit_memo)}';" }
        format.json { render :show, status: :ok, location: @credit_memo }
      else
        flash[:errors] = @credit_memo.errors.full_messages
        @search = @credit_memo.credit_line_items.ransack(params[:q])
        @line_items = @search.result.page(params[:page])
        @account = @credit_memo.account

        @customer_accounts = @vendor.customer_accounts.active.order('fully_qualified_name ASC')
        @shipping_methods = @account.vendor.shipping_methods
        format.html { redirect_to edit_manage_credit_memo_path }
        format.json { render json: @credit_memo.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @credit_memo.destroy
    respond_to do |format|
      format.html { redirect_to spree_manage_credit_memos_url, notice: 'Credit memo was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def variant_search
    @vendor = current_company
    @credit_memo = @vendor.credit_memos.friendly.find(params[:credit_memo_id]) rescue nil
    # @variants = @vendor.variants_for_sale
    # using showable variants because customer requested to be able to add
    # items that are for_purchase only :(
    @variants = @vendor.showable_variants
                       .active
                       .includes(:product, :option_values)
                       .order('full_display_name asc')
    respond_with(@variants)
  end

  def customer_accounts
    if params[:credit_memo_number].present?
      @credit_memo = current_vendor.credit_memos.find_by_number(params[:credit_memo_number])
    end
    @account_id = params[:account_id]
    @customer_account = current_vendor.customer_accounts.find(@account_id)
    @account = @customer_account
    @account_address_ship = @customer_account.default_ship_address
    @account_address_bill = @customer_account.bill_address
    if @credit_memo && @customer_account
      @credit_memo.update_columns(
        account_id: @account_id
      )
    end
    @customer = @customer_account.customer
    @vendor = current_company
    @users = @customer_account.users.where(company_id: @customer_account.customer_id).order('lastname asc')

    respond_to do |format|
     format.js {render :customer_accounts}
    end
  end

  def update_credit_memo_line_items_position
    params[:credit_memo].each do |key,value|
      Spree::CreditLineItem.find(value[:id]).update_attribute(:position, value[:position])
    end
    render :nothing => true
  end

  def add_line_item
    errors = []
    begin
      @credit_memo = current_vendor.credit_memos.friendly.find(params[:id])
      @variant = current_vendor.variants_including_master.find(params[:variant_id])
      @avv = @credit_memo.account.account_viewable_variants.where(variant_id: @variant.id).first
      @credit_memo.add_many({params[:variant_id] => {quantity: params[:variant_qty].to_f, price: @avv.try(:price)}}, {})
      @line_item = @credit_memo.line_items.where(variant_id: params[:variant_id]).last
      @credit_memo.reload
    rescue Exception => e
      errors = [e.message]
    end

    flash.now[:errors] = errors if errors.any?
    render :add_line_item
  end

  def unpopulate
    error = nil
    @line_item = Spree::CreditLineItem.find_by_id(params[:line_item_id])
    if @line_item
      @credit_memo = @line_item.credit_memo
      if @line_item.destroy
        @credit_memo.reload.persist_totals
      else
        error = "Could not remove item."
      end
    end

    respond_with(@credit_memo, @line_item) do |format|
      format.js {flash.now[:error] = error}
    end
  end

  private

  def set_vendor
    @vendor = current_vendor
  end

  def set_credit_memo
    @credit_memo = @vendor.credit_memos.friendly.find(params[:id])
  end

  def credit_memo_params
    params.require(:credit_memo).permit!
  end
end
