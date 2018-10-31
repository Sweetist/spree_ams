Spree::Api::OrdersController.class_eval do

  def index
    authorize! :index, Spree::Order
    @orders = current_api_user.company.sales_orders.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
    respond_with(@orders)
  end

  def create
    authorize! :create, Spree::Order
    order_user = if @current_user_roles.include?('admin') || @current_user_roles.include?('vendor') && order_params[:user_id]
      Spree.user_class.find(order_params[:user_id])
    else
      current_api_user
    end

    import_params = if @current_user_roles.include?("admin") || @current_user_roles.include?('vendor')
      params[:order].present? ? params[:order].permit! : {}
    else
      order_params
    end

    import_params['vendor_id'] = current_vendor.id
    @order = Spree::Core::Importer::Order.import(order_user, import_params)
    respond_with(@order, default_template: :show, status: 201)
  end

  private

  def find_order(lock = false)
    @order = current_api_user.company.sales_orders.lock(lock).friendly.find(params[:id]) rescue nil
  end

end
