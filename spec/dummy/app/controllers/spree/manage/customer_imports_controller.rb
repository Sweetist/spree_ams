class Spree::Manage::CustomerImportsController < Spree::Manage::BaseController
  before_action :ensure_write_permission, only: [:index, :new, :create, :show, :destroy]

  def index
    @imports = current_vendor.customer_imports.order("created_at desc")
  end

  def new
    @customer_import = current_vendor.customer_imports.new
  end

  def create
    @customer_import = current_vendor.customer_imports.new(customer_import_params)
    if @customer_import.save
      Sidekiq::Client.push('class' => CustomerImportWorker, 'queue' => 'imports', 'args' => [@customer_import.id, current_vendor.id])
      redirect_to manage_customer_imports_path, flash: { success: "Import has been queued and will be processed shortly!" }
    else
      flash.now[:errors] = @customer_import.errors.full_messages
      render :new
    end
  end

  def show
    @customer_import = current_vendor.customer_imports.find_by_id(params[:id])
    respond_with(@customer_import)
  end

  def verify
    @customer_import = current_vendor.customer_imports.find(params[:customer_import_id])
    Sidekiq::Client.push('class' => CustomerImportWorker, 'queue' => 'imports', 'args' => [@customer_import.id, current_vendor.id])
    redirect_to manage_customer_imports_path, flash: { success: "Import has been queued for verification and will be processed shortly!" }
  end

  def import
    @customer_import = current_vendor.customer_imports.find(params[:customer_import_id])
    if @customer_import.status == 2
      @customer_import.update_columns(status: 4) #set to 'Queued' if verified
    end
    Sidekiq::Client.push('class' => CustomerImportWorker, 'queue' => 'imports', 'args' => [@customer_import.id, current_vendor.id])
    redirect_to manage_customer_imports_path, flash: { success: "Import has been queued for import and will be processed shortly!" }
  end

  def destroy
    @customer_import = current_vendor.customer_imports.find(params[:id])
    @customer_import.destroy!
    redirect_to manage_customer_imports_path, flash: { success: "Import has been deleted!" }
  end

  private

  def customer_import_params
    params.require(:customer_import).permit(:file, :encoding, :delimer, :replace, :proceed, :proceed_verified)
  end

  def ensure_write_permission
    if current_spree_user.cannot_read?('basic_options', 'customers')
      flash[:error] = 'You do not have permission to view customers'
      redirect_to manage_path
    elsif current_spree_user.cannot_write?('basic_options', 'customers')
      flash[:error] = 'You do not have permission to edit customers'
      redirect_to manage_accounts_path
    end
  end

end
