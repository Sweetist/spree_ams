class Spree::Manage::VendorImportsController < Spree::Manage::BaseController
  before_action :ensure_write_permission, only: [:index, :new, :create, :show, :destroy]

  def index
    @imports = current_company.vendor_imports.order("created_at desc")
  end


  def new
    @vendor_import = current_company.vendor_imports.new
  end 

  def create
    @vendor_import = current_company.vendor_imports.new(vendor_import_params)
    if @vendor_import.save
      Sidekiq::Client.push('class' => VendorImportWorker, 'queue' => 'imports', 'args' => [@vendor_import.id, current_company.id])
       redirect_to manage_vendor_imports_path, flash: { success: "Import has been queued and will be processed shortly!" }
    else
      flash.now[:errors] = @vendor_import.errors.full_messages
       render :new
    end
  end

  def import
    @vendor_import = current_company.vendor_imports.find(params[:vendor_import_id])
    if @vendor_import.status == 2
      @vendor_import.update_columns(status: 4) #set to 'Queued' if verified
    end
    Sidekiq::Client.push('class' => VendorImportWorker, 'queue' => 'imports', 'args' => [@vendor_import.id, current_company.id])
    redirect_to manage_vendor_imports_path, flash: { success: "Import has been queued for import and will be processed shortly!" }
  end

  def verify
    @vendor_import = current_company.vendor_imports.find(params[:vendor_import_id])
    Sidekiq::Client.push('class' => VendorImportWorker, 'queue' => 'imports', 'args' => [@vendor_import.id, current_company.id])
    redirect_to manage_vendor_imports_path, flash: { success: "Import has been queued for verification and will be processed shortly!" }
  end

  def show
    @vendor_import = current_company.vendor_imports.find_by_id(params[:id])
    respond_with(@vendor_import)
  end

  def destroy
    @vendor_import = current_company.vendor_imports.find(params[:id])
    @vendor_import.destroy!
    redirect_to manage_vendor_imports_path, flash: { success: "Vendor has been deleted!" }
  end

  private

  def vendor_import_params
    params.require(:vendor_import).permit(:file, :encoding, :delimer, :replace, :proceed, :proceed_verified)
  end
 
  def ensure_write_permission
    if current_spree_user.cannot_read?('vendors', 'purchase_orders')
       flash[:error] = 'You do not have permission to view vendors'
       redirect_to manage_path
    elsif current_spree_user.cannot_write?('vendors', 'purchase_orders')
       flash[:error] = 'You do not have permission to edit vendors'
       redirect_to manage_accounts_path
    end
  end
end
